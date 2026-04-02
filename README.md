![BATML graphic](https://github.com/ecoObs-Lab/BATML/blob/main/BATML.jpg?raw=true)

# BATML
Bat calls, bat call handling, bat call analysis and machine learning = BATML


BATML is a derivate of the ecoObs software and call analysis tools. It contains a package BatSoundHandling for loading, saving and displaying sound. It also includes machine learning models and aspects for automated, AI call identification. All the tools were tailored to work with the variety of mid-european bat species.

## Swift package
Swift package: [BatSoundHandling](https://github.com/ecoObs-Lab/BatSoundHandling/)

The package contains classes to load audio files, create sonagrams, find bat calls and a simple example for an UI showing waveform and sonagram.

## Example application BATMLTool
Currently work in progress a simple application showing the use of BatSoundHandling in combination with CoreML for sonagram based species identification. It reads files, if available laods former batIdent or bcAdmin identifications and allows to go through found calls and gives id results. These results are based on either a Resnet50 model or a FeaturePrint model and are evaluated hierarchically. Using the Batch identify button identifies all found calls within the file and gives the result for each and overall on the right side.
![BATML graphic](https://github.com/ecoObs-Lab/BATML/blob/main/images/BATMLToolUI.png?raw=true)

## Example application FeedingBuzzer
A small tool built around an object detection model created using CreateML. It is based on a TransferLearning model trained with roughly 200 signals of either feeding buzz or pipistrelle social call. The application loads all sound files within a selected folder, creates sonagrams of the sound files and uses the model to detect possible events of type Feeding or Social. The sound files for training all had a high SNR and 500 kHz samplerate. Using files with low SNR or lower sampling rate will detoriate results. You can adjust the sonagram settings to improve signal detection.

![BATML graphic](https://github.com/ecoObs-Lab/BATML/blob/main/images/FBMainWindow.png?raw=true)
![BATML graphic](https://github.com/ecoObs-Lab/BATML/blob/main/images/FBSonaAdjust.png?raw=true)
