[![Awesome](https://cdn.rawgit.com/sindresorhus/awesome/d7305f38d29fed78fa85652e3a63e154dd8e8829/media/badge.svg)](https://github.com/sindresorhus/awesome)

# OrgaMovie Macro

This FiJi/ImageJ macro takes any number 4D (xyzt) _\*.nd2_ image files of organoids and creates color-coded (for depth) time-lapse movies (see fig below).  
The code is a fully automated adaptation of a macro (version 2016_03_24) previously created by Bas Ponsioen and  René Overmeer, first published in _[Targeting mutant RAS in patient-derived colorectal cancer organoids by combinatorial drug screening](https://elifesciences.org/articles/18489)_, (eLife 2016;5:e18489 doi: 10.7554/eLife.18489).

<p align="center">
    <img src="https://user-images.githubusercontent.com/14219087/114186287-f4473580-9946-11eb-99b2-1f3d73b78a69.png" width=75%>
</p>

The macro will not run on recent versions of ImageJ. The most recent version of ImageJ that this has been stably tested on is 1.49b. Also, the macro currently only works from the workstation (DED-KOPS-001) in the Hubrecht Lab (2nd floor student room). If either of these is limiting for you, please talk to me to figure out a solution.

I have noticed that many people have their own installation of FiJi on their account. However, there is also a common installation of FiJi on the D-drive (strictly speaking FiJi is not installed, but just exists on the disk). I have installed this plugin-set **only on the common FiJi installation**. I recommend you delete your own insance of FiJi if you are not using it for anything else and always work from the common one, which is located under _D:\FiJi.app_, and create a shortcut for _ImageJ-win64.exe_ on your desktop or taskbar.

# Running the OrgaMovie Macro on the Workstation (DED-KOPS-001)

1) Delete old files from D:\ANALYSIS DUMP. This is not essential but avoids confusion with previous analyses.
    - Delete all folders called _Queue Exp \[\#\]_.
    - Delete all _\*.txt_ files.
3) Start FiJi from the common folder ***D:\Fiji.app\\***.
    - Some accounts have an additional installation of FiJi on their own accounts. However, the macro is only stored on the common account, so make sure you run it from the location above
5) Start OrgaMovie macro by hitting F11, or go to _Plugins > OrgaMovies > OrgaMovie Start_.
6) Input your favorite settings (see below).
7) Choose input folder where your raw data (_\*.nd2_ files) are located.
    - Please work from local or external hard disks and NOT from the server. 
8) Wait overnight (rough time estimate: ~14-22h).
9) Collect your output data from _D:\ANALYSIS DUMP\\\_Movies\_\[exp-name\]\\_.
10) Check that your movies are ok and then delete them from the analysis dump to avoid crowding the local HD.

# Macro Settings

## Main Settings Dialog
<img src="https://user-images.githubusercontent.com/14219087/115407951-c12b5e80-a1f0-11eb-9efc-500a5c805bc6.PNG" width=50%>

#### General Settings
- Input filetype: currently the only option is '.nd2'.
- Channel number: set the channel to use in terms of channel order (so N<sup>th</sup> channel) 
    - Can be ignored if single-channel (i.e. single-color) data is used.
    - Because false colors are used to signify depth, it is unclear how to implement multi-channel depth in this macro. Talk to me if you are interested in this to see if we can figure something out.
- Time interval: set the interval (in minutes) between consecutive frames.
- Experiment name: Used for output file naming. Set a prefix for all output files, which is then combined with the file naming setting below to create unique filenames for each movie.
    - Default is your windows account + the current date in yymmdd format.
#### Movie Output Settings
- Output format: Choose whether output videos should be in between _\*.avi_ or _\*.tif_ or both.
    - TIFs are easier to use for downstream analysis in ImageJ but require significantly more diskspace than AVIs (~25-50x larger files).
- Frame rate: The frame rate of the output movie (for _\*.avi_). Set how many seconds each frame stays in view when playing the movie.
    - I copied this setting from original macro, but I'm not sure it does anything. I have the impression that all AVIs are 20 seconds long, independent of number of frames.
- Output naming: What to use after the prefix (set above) to name individual output movies. Options are:
  - _linear_ = number movies consecutively from 1-N.
  - _filename_ = use the original filename (minus the extension).
  - _file index_ = use the original filename until the first underscore ( \_ ). Often filenames are numbered by the microsope software and this number is repeated after the underscore. E.g., the output resulting from _Point0004_Seq0004.nd2_, will be named _\[exp-name\]\_Point0004.avi_.
#### Automation Settings (on/off)
- Drift correction: Correct for organoid drifting or jittering during acquisition.
    - Uses _[MultiStackReg](http://bigwww.epfl.ch/thevenaz/stackreg/)_ plugin (default in FiJi) to correct drift and shaking in movies.
    - If unchecked: the organoid will move across the frame as happened during filming. As a knock-on effect, this will require a larger crop-area (see next setting) leading to larger output file size.
    - Note that the drift correction can lead to movies where it appears that a blacked out region is 'wiping' across your movie. This is in fact the organoid moving out of the field of view.
- Auto-cropping: Detects portion of frame (XY) that is visited by the organoid in any Z or T and crops around this.
    - If multiple organoid regions are found, cropping occurs around the largest region only. 
    - If unchecked: the entire frame is used, leading to (unnecessarily) large file sizes and more cluttered movies. 
    - See default automation settings for more details.
- Auto-contrasting: Automatically detects intensity values to use for contrasting (green and blue in original manual version of the macro).
    - If unchecked: dimmest and brightest pixel values are used, which tends to not give great contrast but also no pixels are overexposed or lost as background.
    - Contrasting cannot be easily adjusted in the resulting output, as RGB images/movies are produced.
    - Ideal contrasting occurs with a lower threshold around the dimmest signals within the organoid and an upper threshold around the value of the brightest (non-apoptotic) pixels in the organoid.
    - See default automation settings for more details on thresholding.
- Last timepoint detection: Finds the last timepoint where an organoid is still visible within the frame. This is based on the coefficient of variation (mean/stdev) of all pixel values in the frame. The last timepoint considered is the first timepoint found where this coefficient is detected. 
    - **Turn off for low signal movies to avoid cutting them short!**
    - If unchecked: all frames of the movie are included in the output, which will lead to (unnecessarily) large file sizes.
    - See default automation settings for more details.
- Change default settings: If this is checked, another dialog will be opened after this to set default automation settings.
    - If few movies turn out imperfect, try running those manually (press F10) rather than changing the settings for all movies.
    - If many movies turn out weird, perhaps changing default parameters can help. See below for details on these.

## Automation Settings Dialog
If few movies turn out imperfect, try running those manually (press F10) rather than changing the settings for all movies. If many movies turn out weird, perhaps changing default parameters can help.

<img src="https://user-images.githubusercontent.com/14219087/115743925-63cf1300-a392-11eb-867f-796c64fce8a7.png" width=50%>

#### Auto-crop Settings
- Minimum organoid size: the minimum organoid size (in µm<sup>2</sup>) detected to crop around.
    - If no organoid of this size or larger is found, then the entire frame is used.
- Boundary around organoid: the number of pixels around the extreme edges of the organoid included in the cropped region.
#### Contrast Automation Settings
- Minimum threshold method: Choose between the ImageJ default threshold methods to detect brightness of background pixels.
- Minimum brightness multiplier: Multiplier for dimmest pixel.
    - Increase to make background dimmer, but you may lose some dim foreground pixels.
- Percentile overexposed pixels: The percentile of pixels (from the max_Z-max_T projection) that is overexposed.
    - Higher values create brighter movies, but also will also include more overexposed pixels.
    - A good value for this is highly dependent on whether or not _Drift correction_ and _Auto-crop_ are used, as both of these influence the proportion of the frame that is occupied by background pixels.
        - The most consistent result is obtained if both _Drift correction_ and _Auto-crop_ are active.
- Gamma factor (copied from original macro). Applies a [gamma correction](https://en.wikipedia.org/wiki/Gamma_correction) on the output images. 
    - The original macro stated "brings low and high intensities together", but I don't fully understand what a gamma correction does.
- Multiply factor (copied from original macro): I don't know what this setting does, but it was present in the original macro.
    - The original macro stated "for depth coded channel", but it is unclear to me what this setting changes.
#### Time-crop Settings
- CoV cutoff: Cut-off value for coefficient of variation (mean/stdev) for detecting last time-point. Higher values will include more fuzzy/empty frames.
- Minimum length: Minimum length of movie in case CoV cut-off is reached previously. This is mainly included as a workaround for movies that reach the CoV from frame 1, which leads to a crash.
