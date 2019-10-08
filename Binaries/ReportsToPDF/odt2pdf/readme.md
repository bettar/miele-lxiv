We did this on mac OS X 10.14

1. You need **LibreOffice SDK** to build this tool. Download it at <http://www.libreoffice.org/download>

	- [LibreOffice 6.3.2 MacOS x86-64 sdk](https://donate.libreoffice.org/home/dl/SDK/6.3.2/3970/LibreOffice_6.3.2_MacOS_x86-64_sdk.dmg)

- Copy the LibreOffice SDK dir to somewhere safe, for example `~/Downloads/LibreOffice6.1_SDK`
- Change to that directory.

		$ cd ~/Downloads/LibreOffice6.3_SDK
- Enter the LibreOffice SDK environment by using the setsdkenv_unix script.

		$ sh setsdkenv_unix

	The first time, it'll ask a bunch of things. Here's how I configured it:

<pre>
************************************************************************
*
* SDK environment is prepared for MacOSX
*
* SDK = ~/Downloads/LibreOffice6.1_SDK
* Office = /Applications/LibreOffice.app
* Make = /usr/bin
* Zip = /usr/bin
* cat = /bin
* sed = /usr/bin
* C++ Compiler = /usr/bin
* Java = /usr
* SDK Output directory = ~/Documents/LibreOffice6.3_SDK
* Auto deployment = YES
* 
************************************************************************
</pre>

FYI, this results in an environment with added settings:

<pre>
CLASSPATH=/Applications/LibreOffice.app/Contents/Resources/java/juh.jar:/Applications/LibreOffice.app/Contents/Resources/java/jurt.jar:/Applications/LibreOffice.app/Contents/Resources/java/ridl.jar:/Applications/LibreOffice.app/Contents/Resources/java/unoloader.jar:/Applications/LibreOffice.app/Contents/Resources/java/unoil.jar:OFFICE_HOME=/Applications/LibreOffice.appOFFICE_PROGRAM_PATH=/Applications/LibreOffice.app/Contents/MacOSOO_SDK_CAT_HOME=/binOO_SDK_CPP_HOME=/usr/binOO_SDK_HOME=/Users/lxiv/Downloads/LibreOffice6.1_SDKOO_SDK_JAVA_HOME=/usrOO_SDK_MAKE_HOME=/usr/binOO_SDK_NAME=LibreOffice6.3_SDKOO_SDK_SED_HOME=/usr/binOO_SDK_URE_BIN_DIR=/Applications/LibreOffice.app/Contents/MacOSOO_SDK_URE_JAVA_DIR=/Applications/LibreOffice.app/Contents/Resources/javaOO_SDK_URE_LIB_DIR=/Applications/LibreOffice.app/Contents/FrameworksOO_SDK_ZIP_HOME=/usr/binPATH=/usr/bin:/usr/bin:/bin:/usr/bin:/usr/bin:/usr/bin:~/Downloads/LibreOffice6.3_SDK/bin:~/Documents/LibreOffice6.3_SDK/LibreOffice6.3_SDK/MACOSXexample.out/bin:/Applications/LibreOffice.app/Contents/MacOS:/Applications/LibreOffice.app/Contents/MacOSSDK_AUTO_DEPLOYMENT=YES
UNO_PATH=/Applications/LibreOffice.app/Contents/MacOS</pre>

---
### Build our tool

- Normally we would just change to the *odt2pdf* directory and launch the build process:

	(Don't just do this)

		$ cd path/to/odt2pdf
		$ touch odt2pdf.cxx
		$ make

	- On macOS 10.14 it gives an error: `dyld: Library not loaded: @__VIA_LIBRARY_PATH__/libunoidllo.dylib`
	- Trying to solve it by doing `$ export DYLD_LIBRARY_PATH=/Applications/LibreOffice.app/Contents/Frameworks` doesn't resolve the issue
	- A succesfull workaround is shown in [How to compile Java examples in SDK on Mac](https://ask.libreoffice.org/en/question/90228/how-to-compile-java-examples-in-sdk-on-mac/) basically all you have to do is:

	(Do this only once)

			$ mkdir ~/fakebin
			$ cp /bin/bash /usr/bin/make ~/fakebin

	(Do this every time)

			$ SHELL=~/fakebin/bash ~/Downloads/LibreOffice6.3_SDK/setsdkenv_unix
			$ cd path/to/odt2pdf
			$ ~/fakebin/make SHELL="$SHELL"

	If everything has worked out fine, a bunch of stuff got created in `$OO_SDK_OUT`, and in addition we have the binary at `path/to/odt2pdf/build/odt2pdf`

---
### Run our tool

- However, this binary relies on LibreOffice to be launched with SDK support. You must execute this first (my tests tell that it doesn't matter if LibreOffice is already running or not)
	Check that `soffice` is available

		$ which soffice
		/Applications/LibreOffice.app/Contents/MacOS/soffice

		$ soffice "--accept=socket,host=localhost,port=2083;urp;StarOffice.ServiceManager" &

	After that, it should be working. 

		$ odt2pdf -env:URE_MORE_TYPES=file:///Applications/LibreOffice.app/Contents/Resources/types/offapi.rdb path/to/test.odt path/to/output.pdf
		Error: Connector : couldn't connect to socket (Connection refused)

	If you need to quit LibreOffice, you can use

		$ killall soffice

---
So, now that we have been able to compile the binary, let's see what we need to execute it without the SDK, on client machines. On a clean terminal on the same computer we built the binary on, this command allows `odt2pdf` to execute successfully.

		$ export DYLD_LIBRARY_PATH=/Applications/LibreOffice.app/Contents/MacOS/urelibs

What about other computers where the SDK is not even installed?

On a clean Mac OS X 10.6.8 install, we copied LibreOffice to the Applications directory, and odt2pdf (and test.odt) to the desktop. We then opened a terminal and executed:

	$ cd ~/Desktop
	$ export DYLD_LIBRARY_PATH=/Applications/LibreOffice.app/Contents/MacOS/urelibs
	$ soffice "--accept=socket,host=localhost,port=2083;urp;StarOffice.ServiceManager" &
	$ ./odt2pdf -env:URE_MORE_TYPES=file:///Applications/LibreOffice.app/Contents/basis-link/program/offapi.rdb test.odt test.pdf

And it worked.