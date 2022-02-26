#!/bin/bash
# SCRIPT NAME: simple-http-upload-server.sh
# PURPOSE: Hosts a simple http server that has a field to select a file and a button to upload it to the server.
# When the server receives it, the uploaded file name is printed standard out.
# Uploaded files are saved in the current working directory.
# DEPENDENCIES: nc (netcat - OpenBSD), bash, awk
# DATE WRITTEN: 02/19/22
# WRITTEN BY: Craig S
# MODS:


# Constants
# Port the server will be hosted on.
HOST_PORT="8080"
# Hostname of the current system - used to gernate a link.
HOSTNAME="localhost"

# Main logic

echo "Setting up server at: 'http://$HOSTNAME:$HOST_PORT'."

# Main server loop to receive connections and handle accordingly
while true ; do
  # Determine a name for the current file
  # Only create a new file if the previous file does not exist or the previous file has data.
  #if [ -z "$cUploadFile" ] \
  #  || ( [[ "$(du -b "$cUploadFile")" =~ ^([0-9]+) ]] &&  [ "${BASH_REMATCH[1]}" -gt 0 ] ) ; then
    # If this is not the first file created, then we must have just saved a file that was uploaded.
    # Here, we print out that file name.
 #   if [ -n "$cUploadFile" ] ; then
 #     echo "File uploaded as '$cUploadFile' with size ${BASH_REMATCH[1]} bytes."
 #   fi

 #   cUploadFile="$(mktemp 'upload.XXX')"
 # fi
  
  # Send the HTML page to the browser.
  # The code after nc (netcat) parses out the uploaded http "multipart" form data and saves it to a file.
  # Note that the 'sub(/\r$/,"")' calls remove the \r from the Windows newline characters that are
  # provided by the browser.
  echo -e "HTTP/1.0 200\r\nServer: Test\r\nContent-Type:text/html\r\n\r\n<form method=post action=/ enctype=multipart/form-data><input name=upload type=file multiple><input type=submit></form>" | \
        nc -N -l $HOST_PORT | tee -a out | \
        LC_ALL=C awk '
          # Functions
          # Handles when the current file upload is done.
          function fileUploadDone(){
            print("File uploaded as \"" cFileName "\" with a size of " iFileBytes " bytes.");
          }


          # Main logic

          # Handle the start of a new subsection OR break into the next subsection, respectively.
          ((lInData == 0 && /^--/) || (lInData == 1 && ($0 ~ "^" cBoundary "\r$" )) ){
            # If this is not the first subsection, then print that we finished a download.
            if(lInData == 1){
              fileUploadDone();
            }
            sub(/\r$/, "");
            # Store the boundary string and that we are now in the data block. Also set default file name.
            # We also initialize the file size counter and reset the last line checker variable.
            cBoundary=$0;
            lInData=1;
            cFileName="upload";
            iFileBytes=0;
            lIsMaybeLastLine=0;
            # Parse through the data headers
            while($0 != ""){
              #Debug -- print("Skipping line: " $0);
              getline;
              sub(/\r$/, "");
              # Check if we can pull out the file name for this file we will save the upload to.
              for(i = 1; i <= NF; ++i){
                if($i ~ /filename=".*"/){
                  # Found the file name, remove the name="" part and leave us with just the file name itself.
                  # We also remove any "/" characters to prevent changing directories.
                  cFileName=$i;
                  gsub(/^filename="/,"",cFileName);
                  gsub(/"$/, "", cFileName);
                  gsub(/\//, "", cFileName);
                } # If we found the file name
              } # for each field.
            } # While the line is not blank.
            # Move past the first blank line (not part of data).
            getline

            # Make sure the uploaded file exists and is empty
            printf "" > cFileName;
          }

          # Handle the end of the last subsection
          ($0 ~ "^" cBoundary "--\r$"){
            lInData=0
            fileUploadDone();
          }
          
          # Handle any line the data of a section (print to current file).
          # We do not add the ending \r\n since this might be the last line (until we know there is
          # another line available.
          lInData {
            # Handle if the previous line was maybe the last (we thought it might be, but were wrong,
            # so print out the \r\n that we skipped).
            if(lIsMaybeLastLine){
              print "\r" >> cFileName;
              lIsMaybeLastLine=0;
            }

            # If the line ends in \r (then it ends in \r\n) and it may be the start of the end of this
            # current subsection.
            if($0 ~ /\r$/){
              # This might be the last line, only print out the line itself (not the \r\n part).
              lIsMaybeLastLine=1;
              cCurrentLine=$0
              sub(/\r$/, "", cCurrentLine);
            } else {
              # Do include the newline character at the end since this is not the last line in the data.
              cCurrentLine=$0 "\n";
            }

           # Print out the current line (without an implicit newline -- printf).
           printf "%s", cCurrentLine >> cFileName;
           iFileBytes += length(cCurrentLine);
          };
        '
done # while true; do
