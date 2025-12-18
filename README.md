# ConcentricRingIntensityApp (MATLAB)

ConcentricRingIntensityApp is a lightweight MATLAB App Designer GUI for quantifying radial (concentric) fluorescence intensity distributions from image z-stacks. The app loads multi-page TIFF files, computes either a maximum or sum intensity projection, and measures per-ring signal statistics from user-defined regions of interest.

Two ring-generation algorithms are provided. Option A creates concentric elliptical rings by iteratively expanding an initial ellipse ROI by a fixed pixel step, which closely mirrors macros based on FIJI 'Enlarge ROI'. Option B generates equal-area concentric rings that converge toward the nucleus centroid, based on a centroid-corrected distance map computed within a segmented cell ROI. 

Option B is inspired by the ImageJ/FIJI workflow developed by the Molecular Imaging Platform - IBMB (https://github.com/MolecularImagingPlatformIBMB/ringIntensityDistribution
). The MATLAB implementation presented here is an independent reimplementation adapted for interactive use within App Designer.

The app provides per-ring measurements including area, mean intensity, integrated density, and percent of total signal, with visual overlays of ring boundaries and CSV export for downstream analysis. It requires MATLAB R2021b or newer and the Image Processing Toolbox (tested in MATLAB R2022b).
