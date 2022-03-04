[![Awesome](https://cdn.rawgit.com/sindresorhus/awesome/d7305f38d29fed78fa85652e3a63e154dd8e8829/media/badge.svg)](https://github.com/sindresorhus/awesome)

# OrgaMovie Macro

This FiJi/ImageJ macro takes any number 4D (xyzt) _\*.nd2_ image files of organoids and creates color-coded (for depth) time-lapse movies (see example below).  

https://user-images.githubusercontent.com/14219087/153618145-6f403f22-9c2a-4beb-8de5-55ab82c4a644.mp4


This macro is based on another [macro](https://github.com/DaniBodor/OrgaMovie) previously created by Bas Ponsioen and René Overmeer, first published in _[Targeting mutant RAS in patient-derived colorectal cancer organoids by combinatorial drug screening](https://elifesciences.org/articles/18489)_, (eLife 2016;5:e18489 doi: 10.7554/eLife.18489).


## How to install OrgaMovie
1) [Download](https://github.com/DaniBodor/OrgaMovie_v3/archive/refs/heads/main.zip) this repository by clicking on the link or on the green 'Code' button above and 'Download ZIP' (or use git pull).
2) Extract your zip file
3) Start FIJI and go to _Plugins>Install..._  
    <img src="https://user-images.githubusercontent.com/14219087/153043733-e1f90753-01e7-4e4d-b06d-753f97aff7df.png" width=40%>

4) Select OrgaMovie_v3.ijm from the location you downloaded and unzipped to and save it into you _.../fiji.app/plugins/Scripts/Image/Hyperstacks/_ folder (or some other location you prefer)  
5) Restart FiJi and it will show up in your Image>Hyperstacks menu (or whatever other location you chose)  
    <img align="middle" src="https://user-images.githubusercontent.com/14219087/153886279-068b4ebf-1fbd-413e-bb91-364a03c67622.png" width=40%>


### External content required before you can run the macro
There is a bit of external content required for this macro which may or may not be present on your installation of FiJi. After installing any of these, you need to restart FiJi for it to actually work.  
<img align="right" src=https://user-images.githubusercontent.com/14219087/153417850-0e500496-99b5-48d1-b6ee-7d646df1e794.png width=45%>

You can check which (if any) of these are already installed by hitting Ctrl+l or just l (= lowercase L) in FiJi to open the focus search bar and start typing the plugin/extension name. If it's installed, it will be listed in the Commands list on the left. 

-  There are a couple of color lookup tables (LUTs) that I find work well for the depth coding and maximum projection (see example movie above; these LUTS were originally developed for [this paper](https://elifesciences.org/articles/18489)). Although you can choose your favorite LUT in the settings, I have coded it in a way that it requires you to at least add the default ones to your LUT list. To add them:
    - You can copy them from your download location into your _"...\Fiji.app\luts"_ folder.
    - If you can't find your FiJi location, just run the macro without doing this and it will open the folder for you. Don't forget to restart.
- There are 2 external plugins required for image registraion (drift correction):
    - [MultiStackReg](http://bradbusse.net/downloads.html) can be downloaded from Brad Busse's website.
    - [TurboReg](http://bigwww.epfl.ch/thevenaz/turboreg/) can be downloaded from the EPFL's website or in FiJi by activating the BIG-EPFL update site (see [here](https://imagej.net/update-sites/following) for an explanation on how to do this).
- The macro relies on a tiny bit of Python code for which it needs a plugin called Jython.jar. If this is not yet installed in your FiJi, it will automatically ask if you want to install it. Just click OK.



## Running the macro
1) Put all the raw data you want to process into your input folder (images can be any size and any format that FiJi can handle).
2) Start Fiji and make sure you have no unsaved stuff open, as all images/results/ROIs/Logs/etc will be closed or overwritten without saving.
3) Select _OrgaMovie_v3_ from wherever you installed it (or [create a shortcut](https://imagej.net/learn/keyboard-shortcuts) for it).
    - Occasionally when starting the macro it will crash immediately and Fiji will show an _Exception_ window. Just start the macro again and it should run fine the second time (I've never had the problem pop up twice in a row). I haven't been able to find the source of this error or figure out when and why it happens.
4) Choose your settings ([see below for explanation](https://github.com/DaniBodor/OrgaMovie_v3/edit/main/README.md#orgamovie-settings)), hit _OK_.
    - If you have the macro recorder open, an error message might pop up at this point. You can safely ignore this error and the macro will run just fine, or you can close the recorder to avoid the error appearing.
5) Choose your input folder, hit _Select_.
6) Depending on the size of the files, the macro can take a while to run. At some stages it might seem like nothing is happening, but you can usually see whether it is still running by checking the log window (which states what is currently happening) and/or the status bar of FiJi (i.e. below the clickable icons). To get a better idea of whether it's stuck or not, consider turning on "Print progress duration" in the [Settings](https://github.com/DaniBodor/OrgaMovie_v3/edit/main/README.md#imagej-settings).
7) Your movies (and a log file) will be saved into a subfolder of your input folder called __OrgaMovies_.
8) If the macro finished running without errors, the last line in the log window should read "Run finished".



## OrgaMovie Settings
<img align="right" src="https://user-images.githubusercontent.com/14219087/156580343-04110f84-6cb7-4531-bd97-96def8eee660.png" width=25%>
Your settings will always be at the top of your experiment log, so you can always find back which settings you used in any run.



### Input/output settings
- Input filetype: write the extension of the filetype you want to use (so that all files in the input folder with a different extension are ignored).
- Input channel: set the channel to use in terms of channel order (so N<sup>th</sup> channel).
    - Can be ignored if single-channel (i.e. single-color) data is used.
- Time interval: set the interval (in minutes) between consecutive frames. This is used in the time-stamp of the movie.
- Time-lapse epochs: in case you have used different time intervals throughout the time lapse, you can set the number of epochs (sequence with a certain time interval) here.
    - Example: you imaged overnight every 3 min intervals, then for 24h at 10 min intervals, then the last hour at 3 min intervald again. The number of epochs is *3*.
    - If epochs is set larger than 1, then another dialog will show after this one to set the details.
- Z-step: set the axial step size (in microns). This is used for the color-bar legend.
- Output format: Choose whether output videos should be in between _\*.avi_ or _\*.tif_ or both.
    - TIFs are easier to use for downstream analysis in ImageJ but require significantly more diskspace than AVIs (~25-50x larger files).
- Save separate projections: if this is checked, then the depth and max projections are also saved as separate \*.tifs without any legend, etc (for easy editing in FiJi)

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
- Reduce RAM usage: The macro automatically detects how much RAM is available to FiJi and adjusts the maximum filesize based on this. This should work fine most of the time. Just in case you are having memory issues (or are using a lot of other heavy programs), tick this to halve the RAM used by this macro. If this is still too much, then either close some programs or adjust the memory available to ImageJ in the _"Edit>Options>Memory & Threads..."_ menu. (If ImageJ exceeds the available memory, it usually (but not always) gives a warning that this is the case).
- Print progress duration: if checked, the log will output which process of the macro took how long. This can be useful when working with large files if you want to know whether the macro is stuck or not.
- Save these settings for next time: If checked, the current settings will be stored and automatically loaded next time you run the macro.
    - Remember that your previous settings will be stored in the log from that run so that you don't loose them.
- Load defaults: If checked, the default settings (as in image above) are reloaded. After hitting OK, the dialog window will re-appear and you can still make changes.
    - Note that this will override the 'save settings' from above.

### Epoch Settings
<img align="right" src="https://user-images.githubusercontent.com/14219087/156586456-3b97e676-c447-4527-b5cb-58facc988df1.png" width=33%>

- Time interval X: set the interval (in minutes) between consecutive frames for epoch X.
- Duration X: set the duration (in number of frames) of this epoch.
    - Take care to check exact number of frames used by the microscope as opposed to just calculating the number of frames based on the interval. For example, 18 hours at 3 minute intervals could either mean 360 frames (18 hours * 20 frames/hour) or 361 frames.
    - You can set 0 if it is the last epoch of the series and it will use this interval until the end of the movie. (If the duration for any epoch is set to 0, other epochs down the list are ignored). 
