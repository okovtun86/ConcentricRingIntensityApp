classdef ConcentricRingIntensityApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure

        AxImg matlab.ui.control.UIAxes
        AxPlot matlab.ui.control.UIAxes
        Tbl matlab.ui.control.Table

        BtnLoad matlab.ui.control.Button
        BtnDrawEllipse matlab.ui.control.Button
        BtnDrawCell matlab.ui.control.Button
        BtnDrawNuc matlab.ui.control.Button
        BtnCompute matlab.ui.control.Button
        BtnExport matlab.ui.control.Button
        BtnClearROI matlab.ui.control.Button

        DropProj matlab.ui.control.DropDown
        DropAlg matlab.ui.control.DropDown

        SpinRings matlab.ui.control.Spinner
        SpinStep matlab.ui.control.Spinner

        LblStatus matlab.ui.control.Label
    end

    properties (Access = private)
        Stack
        Proj
        ProjMode = "Max"
        AlgMode = "Option A"

        EllipseROI
        CellROI
        NucROI

        RingMasks
        ResultsTable
        CurrentFile = ""
    end

    methods (Access = private)

        function createUI(app)
            app.UIFigure = uifigure('Name','Concentric Ring Intensity App','Position',[100 100 1180 700]);

            app.AxImg  = uiaxes(app.UIFigure,'Position',[300 210 560 460]);
            app.AxPlot = uiaxes(app.UIFigure,'Position',[300 20  560 170]);
            app.Tbl    = uitable(app.UIFigure,'Position',[870 20  300 650]);

            app.BtnLoad = uibutton(app.UIFigure,'Text','Load TIFF Z-stack','Position',[20 650 260 30], ...
                'ButtonPushedFcn',@(s,e)app.onLoad());

            uilabel(app.UIFigure,'Text','Projection','Position',[20 612 80 20]);
            app.DropProj = uidropdown(app.UIFigure,'Items',{'Max','Sum'},'Value','Max','Position',[110 610 170 25], ...
                'ValueChangedFcn',@(s,e)app.onProjChanged());

            uilabel(app.UIFigure,'Text','Algorithm','Position',[20 575 80 20]);
            app.DropAlg = uidropdown(app.UIFigure,'Items',{'Option A','Option B'},'Value','Option A','Position',[110 573 170 25], ...
                'ValueChangedFcn',@(s,e)app.onAlgChanged());

            uilabel(app.UIFigure,'Text','# Rings','Position',[20 535 80 20]);
            app.SpinRings = uispinner(app.UIFigure,'Limits',[2 50],'Value',4,'Step',1,'Position',[110 533 80 25]);

            uilabel(app.UIFigure,'Text','Step (px)','Position',[200 535 80 20]);
            app.SpinStep = uispinner(app.UIFigure,'Limits',[1 500],'Value',77,'Step',1,'Position',[200 533 80 25]);

            app.BtnDrawEllipse = uibutton(app.UIFigure,'Text','Draw ellipse ROI (A)','Position',[20 480 260 30], ...
                'ButtonPushedFcn',@(s,e)app.onDrawEllipse());

            app.BtnDrawCell = uibutton(app.UIFigure,'Text','Draw cell ROI (B)','Position',[20 440 260 30], ...
                'ButtonPushedFcn',@(s,e)app.onDrawCell());

            app.BtnDrawNuc = uibutton(app.UIFigure,'Text','Draw nucleus ROI (B)','Position',[20 400 260 30], ...
                'ButtonPushedFcn',@(s,e)app.onDrawNuc());

            app.BtnCompute = uibutton(app.UIFigure,'Text','Compute rings + profile','Position',[20 340 260 35], ...
                'ButtonPushedFcn',@(s,e)app.onCompute());

            app.BtnExport = uibutton(app.UIFigure,'Text','Export CSV','Position',[20 295 260 30], ...
                'ButtonPushedFcn',@(s,e)app.onExport());

            app.BtnClearROI = uibutton(app.UIFigure,'Text','Clear ROIs','Position',[20 250 260 30], ...
                'ButtonPushedFcn',@(s,e)app.onClearROIs());

            app.LblStatus = uilabel(app.UIFigure,'Text','Status: ready','Position',[20 20 260 200], ...
                'VerticalAlignment','top','WordWrap','on');
        end

        function setStatus(app, txt)
            app.LblStatus.Text = "Status: " + string(txt);
            drawnow limitrate
        end

        function t = titleLine(app)
            if app.CurrentFile == ""
                t = sprintf('Projection: %s', app.ProjMode);
            else
                [~,nm,ext] = fileparts(app.CurrentFile);
                t = sprintf('%s%s | Projection: %s', nm, ext, app.ProjMode);
            end
        end

        function showImage(app)
            if isempty(app.Proj), return; end
            imagesc(app.AxImg, app.Proj);
            axis(app.AxImg,'image');
            colormap(app.AxImg,'gray');
            app.AxImg.XTick = [];
            app.AxImg.YTick = [];
            title(app.AxImg, app.titleLine());
        end

        function deleteROI(app, roiObj)
            if ~isempty(roiObj) && isvalid(roiObj)
                delete(roiObj);
            end
        end

        function proj = computeProjection(app, stack, projMode)
            projMode = lower(char(projMode));
            sz = size(stack);
            if numel(sz) < 3, sz(3) = 1; end
            H = sz(1); W = sz(2); Z = sz(3);

            switch projMode
                case 'max'
                    proj = single(stack(:,:,1));
                    for k = 2:Z
                        proj = max(proj, single(stack(:,:,k)));
                        if mod(k, 10) == 0, drawnow limitrate; end
                    end
                case 'sum'
                    proj = zeros(H, W, 'single');
                    for k = 1:Z
                        proj = proj + single(stack(:,:,k));
                        if mod(k, 10) == 0, drawnow limitrate; end
                    end
                otherwise
                    error("Unknown projection mode: %s", projMode);
            end
        end

        function setBusy(app, tf)
            if tf
                app.UIFigure.Pointer = 'watch';
                app.BtnLoad.Enable = 'off';
                app.DropProj.Enable = 'off';
                app.DropAlg.Enable = 'off';
                app.BtnDrawEllipse.Enable = 'off';
                app.BtnDrawCell.Enable = 'off';
                app.BtnDrawNuc.Enable = 'off';
                app.BtnCompute.Enable = 'off';
                app.BtnExport.Enable = 'off';
                app.BtnClearROI.Enable = 'off';
            else
                app.UIFigure.Pointer = 'arrow';
                app.BtnLoad.Enable = 'on';
                app.DropProj.Enable = 'on';
                app.DropAlg.Enable = 'on';
                app.BtnCompute.Enable = 'on';
                app.BtnExport.Enable = 'on';
                app.BtnClearROI.Enable = 'on';
                app.onAlgChanged();
            end
            drawnow limitrate
        end

        function onLoad(app)
            [f,p] = uigetfile({'*.tif;*.tiff','TIFF stacks (*.tif, *.tiff)'}, 'Select TIFF z-stack');
            if isequal(f,0), return; end
            app.CurrentFile = fullfile(p,f);

            app.setBusy(true);
            app.setStatus("loading: " + app.CurrentFile);

            try
                app.Stack = tiffreadVolume(app.CurrentFile);
                app.ProjMode = string(app.DropProj.Value);
                app.Proj = app.computeProjection(app.Stack, app.ProjMode);
            catch ME
                app.setStatus("load failed: " + ME.message);
                app.setBusy(false);
                return;
            end

            app.onClearROIs();
            app.showImage();
            app.setStatus("loaded: " + size(app.Stack,1) + "x" + size(app.Stack,2) + "x" + size(app.Stack,3));
            app.setBusy(false);
        end

        function onProjChanged(app)
            app.ProjMode = string(app.DropProj.Value);
            if isempty(app.Stack)
                app.showImage();
                return;
            end

            app.setBusy(true);
            app.setStatus("recomputing projection: " + app.ProjMode);

            try
                app.Proj = app.computeProjection(app.Stack, app.ProjMode);
                app.showImage();
                if ~isempty(app.RingMasks) && ~isempty(app.ResultsTable)
                    app.overlayRings(app.RingMasks);
                    app.plotResults(app.ResultsTable);
                end
                app.setStatus("projection updated: " + app.ProjMode);
            catch ME
                app.setStatus("projection failed: " + ME.message);
            end

            app.setBusy(false);
        end

        function onAlgChanged(app)
            app.AlgMode = string(app.DropAlg.Value);
            if app.AlgMode == "Option A"
                app.SpinStep.Enable = 'on';
                app.BtnDrawEllipse.Enable = 'on';
                app.BtnDrawCell.Enable = 'off';
                app.BtnDrawNuc.Enable = 'off';
            else
                app.SpinStep.Enable = 'off';
                app.BtnDrawEllipse.Enable = 'off';
                app.BtnDrawCell.Enable = 'on';
                app.BtnDrawNuc.Enable = 'on';
            end
        end

        function onDrawEllipse(app)
            if isempty(app.Proj)
                app.setStatus("load an image first");
                return;
            end
            app.deleteROI(app.EllipseROI);
            app.setStatus("draw ellipse, double-click to finish");
            app.EllipseROI = drawellipse(app.AxImg);
            app.EllipseROI.Label = "Ellipse";
            app.EllipseROI.Color = [0 0.8 1];
            app.setStatus("ellipse ROI set");
        end

        function onDrawCell(app)
            if isempty(app.Proj)
                app.setStatus("load an image first");
                return;
            end
            app.deleteROI(app.CellROI);
            app.setStatus("draw cell polygon, double-click to finish");
            app.CellROI = drawpolygon(app.AxImg);
            app.CellROI.Label = "Cell";
            app.CellROI.Color = [0 1 0];
            app.setStatus("cell ROI set");
        end

        function onDrawNuc(app)
            if isempty(app.Proj)
                app.setStatus("load an image first");
                return;
            end
            app.deleteROI(app.NucROI);
            app.setStatus("draw nucleus polygon, double-click to finish");
            app.NucROI = drawpolygon(app.AxImg);
            app.NucROI.Label = "Nucleus";
            app.NucROI.Color = [1 0.8 0];
            app.setStatus("nucleus ROI set");
        end

        function onClearROIs(app)
            app.deleteROI(app.EllipseROI); app.EllipseROI = [];
            app.deleteROI(app.CellROI);    app.CellROI = [];
            app.deleteROI(app.NucROI);     app.NucROI = [];
            app.RingMasks = [];
            app.ResultsTable = [];
            app.Tbl.Data = table();
            cla(app.AxPlot);
            if ~isempty(app.Proj), app.showImage(); end
            app.setStatus("ROIs cleared");
        end

        function ringMasks = ringsOptionA(app, imgSize, ellipseRoi, numRings, ringStepPx)
            baseMask = createMask(ellipseRoi, zeros(imgSize,'like',1));
            ringMasks = cell(numRings,1);
            prev = baseMask;
            ringMasks{1} = prev;

            se = strel('disk', ringStepPx, 0);
            for k = 2:numRings
                grown = imdilate(prev, se);
                ringMasks{k} = grown & ~prev;
                prev = grown;
            end
        end

        function [ringMasks, thresholdsUsed] = ringsOptionB(app, cellMask, nucMask, numRings)
            s = regionprops(nucMask, 'Centroid');
            if isempty(s), error("No nucleus ROI pixels found."); end
            c = s(1).Centroid; XC = c(1); YC = c(2);

            distMap = bwdist(~cellMask);
            boundary = bwperim(cellMask);
            [by, bx] = find(boundary);
            if isempty(bx), error("Cell ROI boundary not found."); end
            dBoundary = hypot(bx - XC, by - YC);
            dmax = max(dBoundary);

            [yy, xx] = ndgrid(1:size(cellMask,1), 1:size(cellMask,2));
            d = hypot(xx - XC, yy - YC);
            d(d < 1e-6) = 1e-6;

            corrected = distMap .* (dmax ./ d);
            corrected(~cellMask) = NaN;

            fracs = (numRings-1:-1:1) / numRings;
            vals = corrected(cellMask);
            vals = vals(~isnan(vals));
            vals = sort(vals, 'ascend');

            thresholdsUsed = zeros(numRings-1,1);
            cumMasks = cell(numRings,1);

            for i = 1:(numRings-1)
                targetFrac = fracs(i);
                idx = max(1, round((1 - targetFrac) * numel(vals)));
                thr = vals(idx);
                thresholdsUsed(i) = thr;
                cumMasks{i} = cellMask & (corrected >= thr);
            end
            cumMasks{numRings} = false(size(cellMask));

            ringMasks = cell(numRings,1);
            for i = 1:(numRings-1)
                ringMasks{i} = cumMasks{i} & ~cumMasks{i+1};
            end
            ringMasks{numRings} = cumMasks{numRings-1};
        end

        function T = measureRings(app, projImg, ringMasks)
            projImg = single(projImg);

            n = numel(ringMasks);
            areaPx = zeros(n,1);
            intDen = zeros(n,1);
            meanI  = zeros(n,1);

            for k = 1:n
                m = ringMasks{k};
                areaPx(k) = nnz(m);
                px = projImg(m);
                if isempty(px)
                    intDen(k) = 0;
                    meanI(k) = NaN;
                else
                    intDen(k) = sum(px);
                    meanI(k)  = mean(px);
                end
            end

            totalIntDen = sum(intDen);
            pctTotal = 100 * intDen / max(totalIntDen, eps);

            T = table((1:n)', areaPx, meanI, intDen, pctTotal, ...
                'VariableNames', {'Ring','AreaPx','Mean','IntDen','PctTotal'});
        end

        function overlayRings(app, ringMasks)
            if isempty(app.Proj), return; end
            imagesc(app.AxImg, app.Proj);
            axis(app.AxImg,'image');
            colormap(app.AxImg,'gray');
            hold(app.AxImg,'on');
            for k = 1:numel(ringMasks)
                visboundaries(app.AxImg, ringMasks{k});
            end
            hold(app.AxImg,'off');
            app.AxImg.XTick = [];
            app.AxImg.YTick = [];
            title(app.AxImg, app.titleLine());
        end

        function plotResults(app, T)
            cla(app.AxPlot);
            if isempty(T), return; end
            plot(app.AxPlot, T.Ring, T.Mean, '-o');
            grid(app.AxPlot,'on');
            xlabel(app.AxPlot,'Ring');
            ylabel(app.AxPlot,'Mean intensity');
            title(app.AxPlot,'Ring mean intensity');
        end

        function onCompute(app)
            if isempty(app.Proj)
                app.setStatus("load an image first");
                return;
            end

            numRings = app.SpinRings.Value;
            app.setBusy(true);

            try
                if app.DropAlg.Value == "Option A"
                    if isempty(app.EllipseROI) || ~isvalid(app.EllipseROI)
                        app.setStatus("Option A requires an ellipse ROI");
                        app.setBusy(false);
                        return;
                    end
                    stepPx = app.SpinStep.Value;
                    app.setStatus("computing Option A rings...");
                    app.RingMasks = app.ringsOptionA(size(app.Proj), app.EllipseROI, numRings, stepPx);
                else
                    if isempty(app.CellROI) || ~isvalid(app.CellROI)
                        app.setStatus("Option B requires a cell ROI");
                        app.setBusy(false);
                        return;
                    end
                    if isempty(app.NucROI) || ~isvalid(app.NucROI)
                        app.setStatus("Option B requires a nucleus ROI");
                        app.setBusy(false);
                        return;
                    end
                    cellMask = createMask(app.CellROI, false(size(app.Proj)));
                    nucMask  = createMask(app.NucROI,  false(size(app.Proj)));

                    if nnz(cellMask) == 0
                        app.setStatus("cell ROI has zero area");
                        app.setBusy(false);
                        return;
                    end
                    if nnz(nucMask) == 0
                        app.setStatus("nucleus ROI has zero area");
                        app.setBusy(false);
                        return;
                    end

                    app.setStatus("computing Option B rings...");
                    [app.RingMasks, ~] = app.ringsOptionB(cellMask, nucMask, numRings);
                end

                app.setStatus("measuring intensities...");
                app.ResultsTable = app.measureRings(app.Proj, app.RingMasks);
                app.Tbl.Data = app.ResultsTable;

                app.overlayRings(app.RingMasks);
                app.plotResults(app.ResultsTable);

                app.setStatus("done");
            catch ME
                app.setStatus("compute failed: " + ME.message);
            end

            app.setBusy(false);
        end

        function onExport(app)
            if isempty(app.ResultsTable)
                app.setStatus("nothing to export (compute first)");
                return;
            end
            [f,p] = uiputfile({'*.csv','CSV (*.csv)'}, 'Save results as CSV', 'ring_profile.csv');
            if isequal(f,0), return; end
            out = fullfile(p,f);
            try
                writetable(app.ResultsTable, out);
                app.setStatus("exported: " + out);
            catch ME
                app.setStatus("export failed: " + ME.message);
            end
        end

    end

    methods (Access = public)

        function app = ConcentricRingIntensityApp
            createUI(app);
            app.onAlgChanged();
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            try
                app.deleteROI(app.EllipseROI);
                app.deleteROI(app.CellROI);
                app.deleteROI(app.NucROI);
            catch
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

    end
end

