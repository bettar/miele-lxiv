This repository contains the source code of Miele-LXIV, the open-source DICOM workstation and viewer.

About Miele-LXIV...

Initially forked from the OsiriX project.

---
## Current features

#### DICOM File Support
- Read and display all DICOM Files (mono-frame, multi-frames)
- Read and display the new MRI/CT multi-frame format (5200 group)
- JPEG Lossy, JPEG Lossless, JPEG-LS, JPEG 2000, RLE
Monochrome1, Monochrome2, RGB, YBR, Planar, Palettes, ...
- Support custom (non-square) Pixel Aspect Ratio
8, 12, 16, 32 bits
- Write 'SC' (Secondary Capture) DICOM Files from any 2D/3D reconstructions
- Read and display all DICOM Meta-Data
- Read AND Write DICOM CD/DVD (DICOMDIR support)
- Export DICOM Files to TIFF, JPEG, Quicktime, RAW, DICOM, PACS
CD/DVD Creation with DICOMDIR support, including cross-platform viewer (Weasis)
- Built-in SQL compatible database with unlimited number of files

#### DICOM Network Support
- Send studies (C-STORE SCU, DICOM Send)
- Receive studies (C-STORE SCP, DICOM Listener)
- Query and Retrieve studies from/to a PACS workstation (C-FIND SCU, C-MOVE SCU, WADO)
- Use Miele-LXIV as a DICOM PACS server (C-FIND SCP, C-MOVE SCP, WADO)
- On-the-fly conversion between all DICOM transfer syntaxes
C-GET SCU/SCP and WADO support for dynamic IP transfers
- DICOM Printing support
- Seamless integration with OsiriX HD for iPhone/iPad
- Seamless integration with any PACS server, including the open-source dcm4chee server

#### Non-DICOM Files Support
- LSM files from Zeiss (8, 16, 32 bits) (Confocal Microscopy)
- BioRadPIC files (8, 16, 32 bits) (Confocal Microscopy)
- TIFF (8, 12, 16, 32 bits), multi-pages
- ANALYZE (8, 12, 16, 32 bits)
- PNG, JPEG, PDF (multi-pages), Quicktime, AVI, MPEG, MPEG4

#### 2D Viewer
- Intuitive GUI
- Customizable Toolbars
- Bicubic Interpolation with full 32-bit pixel pipeline
- Thick Slab for multi-slices CT and MRI (Mean, MIP, Volume Rendering)
- ROIs: Polygons, Circles, Pencil, Rectangles, Point, ... with undo/redo support
- Key Images
- Multi-Buttons and Scroll-wheel mouses supported, including Magic Trackpad support.
- Custom CLUT (Color Look-Up Tables)
- Custom 3x3 and 5x5 Convolution Filters (Bone filters, ...)
- 4D Viewer for Cardiac-CT and other temporal series
- Image Fusion for PET-CT & SPECT-CT exams with adjustable blending percentage
- Image subtraction for XA
- Hanging Protocols
- Tiles export
- 2D Image Registration & Reslicing
- Workspaces
- Plugins support for external functions

#### 3D Post-Processing
- MPR (Multiplanar Reconstruction) with Thick Slab (Mean, MIP, Volume Rendering)
- 3D Curved-MPR with Thick Slab
- 3D MIP (Maximum Intensity Projection)
- 3D Volume Rendering
- 3D Surface Rendering
- 3D ROIs
- 3D Image Registration
- Stereo Vision with Red/Blue glasses
- Export any 3D images to Quicktime, TIFF, JPEG
- All 3D viewers support 'Image Fusion' for PET-CT exams and '4D mode' for Cardiac-CT.

#### Optimization
- Multi-threaded for multi-processors and multi-core processors support
- Asyncronous reading
- OpenGL for 2D Viewer and all 3D Viewers
- Graphic board accelerated, with 3D texture mapping support

#### Expansion & Scientific Research
- Miele-LXIV supports a complete dynamic plugins architecture
- Access pixels directly in 32-bits float for B&W images or ARGB values for color images
- Create and manage windows
- Access the entire Cocoa framework
- Create and manage OpenGL views

#### Based on robust Open-Source components
- Cocoa (OpenStep, GNUStep, NextStep)
- VTK (Visualization Toolkit)
- ITK (Insight Toolkit)
- PixelMed (David Clunie)
- OpenJPEG
- DICOM Offis DCMTK
- OpenGL
- LibTIFF
- LibJPEG

---
## How to Build the Project

As of March 2019 the most convenient way of configuring and building the application is by following the instructions from the README file of this project: <https://github.com/bettar/miele-lxiv-easy>