[![Awesome](https://cdn.rawgit.com/sindresorhus/awesome/d7305f38d29fed78fa85652e3a63e154dd8e8829/media/badge.svg)](https://github.com/sindresorhus/awesome)

# OrgaMovie Macro

This FiJi/ImageJ macro takes any number 4D (xyzt) _\*.nd2_ image files of organoids and creates color-coded (for depth) time-lapse movies (see example below).  

https://user-images.githubusercontent.com/14219087/153039727-4fde4888-3540-4628-b33b-7446a5222de4.mov  

This macro is based on another [macro](https://github.com/DaniBodor/OrgaMovie) previously created by Bas Ponsioen and René Overmeer, first published in _[Targeting mutant RAS in patient-derived colorectal cancer organoids by combinatorial drug screening](https://elifesciences.org/articles/18489)_, (eLife 2016;5:e18489 doi: 10.7554/eLife.18489).


## How to get the macro
1) [Download](https://github.com/DaniBodor/OrgaMovie_v3/archive/refs/heads/main.zip) this repository by clicking on the link or on the green 'Code' button above and 'Download ZIP' (or use git pull).
2) Extract your zip file
3) Start FIJI and go to _Plugins>Install..._ &nbsp;&nbsp;&nbsp; <img align="middle" src="https://user-images.githubusercontent.com/14219087/153043733-e1f90753-01e7-4e4d-b06d-753f97aff7df.png" width=40%>

4) Select OrgaMovie_v3.ijm from the location you downloaded and unzipped to and save it into you _.../fiji.app/plugins/Analyze/_ folder (or some other location you prefer)  
5) Restart FiJi and it will show up in your _Plugins>Analyze_ menu &nbsp;&nbsp;&nbsp; <img align="middle" src="https://user-images.githubusercontent.com/14219087/153043552-0d984d64-351b-4f12-bb03-4bdc5b87dfa5.png" width=50%>


## Running OrgaMovie_v3
1) Put all the raw data you want to process into your input folder (images can be any size and any format that FiJi can handle)
2) Select _OrgaMovie_v3_ from wherever you installed it (or [create a shortcut](https://imagej.net/learn/keyboard-shortcuts))
3) Choose your settings (see below for explanation), hit OK
4) Choose your input folder, hit OK
6) Depending on the size of the files, the macro can take quite a while to run. At some stages it might seem like nothing is happening, but you can usually see whether it is still running by checking the log window (which states what is currently happening) and/or the status bar of FiJi (i.e. below the clickable icons).
7) Your movies (and a log file) will be saved into a subfolder of your input folder called _/_OrgaMovies/_
8) If the macro finished running without errors, the last line in the log window should read "Run finished without crashing."


## OrgaMovie Settings
<img align="right" src="https://user-images.githubusercontent.com/14219087/153222072-d41836bb-7be9-48bc-8043-5a2ba8a209f6.png" width=25%>

### Input/output settings
- Input filetype: write the extension of the filetype you want to use (so that all files in the input folder with a different extension are ignored).
- Input channel: set the channel to use in terms of channel order (so N<sup>th</sup> channel).
    - Can be ignored if single-channel (i.e. single-color) data is used.
    - Because false colors are used to signify depth, it is unclear how to implement multi-channel depth in this macro. Talk to me if you are interested in this to see if we can figure something out.
- Time interval: set the interval (in minutes) between consecutive frames. This is used in the time-stamp of the movie.
- Z-step: set the axial step size (in microns). This is used for the color-bar legend.
- Output format: Choose whether output videos should be in between _\*.avi_ or _\*.tif_ or both.
    - TIFs are easier to use for downstream analysis in ImageJ but require significantly more diskspace than AVIs (~25-50x larger files).
- Save intermediates: if this is checked, then the depth and max projections are also saved as separate \*.tifs without any legend, etc

### Movie settings
- Frame rate: The frame rate of the output movie (for _\*.avi_). Set how many seconds each frame stays in view when playing the movie.
- Apply drift correction: Untick this if you do not want to correct for drift (or jitter) of your movies.
- Depth coding: select look up table (LUT) for depth coding.
- Projection LUT: select look up table (LUT) for the max projection.
- Pixel saturation: sets % of saturated pixels in output. Larger number gives brighter image with a larger proportion of saturated pixels.
- Min intensity factor: multiplication factor for background intensity. Larger number gives brighter image with more dim signals cut off.
- Crop boundary: The macro automatically detects the main signal region. This settings allows you to increase (in each direction) the cropped region surrounding this.
- Scalebar target width: select the ideal width of the scale bar in proportion to the image width. The true width of the scale bar will depend on a round number of microns that gives a scale bar of similar width to this target.

### ImageJ settings
- Reduce RAM usage: The macro automatically detects how much RAM is available to FiJi and adjusts the maximum filesize based on this. This should work fine, but just in case you are using a lot of other heavy programs, tick this to halve the RAM used by this macro. If this is still too much, then either close some programs or adjust the memory available to ImageJ in the _"Edit>Options>Memory & Threads..."_ menu. (If ImageJ exceeds the available memory, it usually (but not always) gives a warning that this is the case).
- Print progress duration: if checked, the log will output which process of the macro took how long.

