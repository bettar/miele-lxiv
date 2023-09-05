//
//  AYDcmPrintSCU.cpp
//  DICOMPrint
//
//  Created by Alessandro Bettarini on 28 Dec 2018
//  Copyright © 2018 bettar. All rights reserved.
//
//  This file is licensed under GNU - GPL v3 license.
//  See file LICENCE for details.
//

#ifndef AYDcmPrintSCU_h
#define AYDcmPrintSCU_h

#include "AYPrintManager.h"

#include <time.h>
#include <iostream>
#include <string>
#include <vector>
#include <list>
//using namespace std;

#include "dcmtk/config/osconfig.h"    /* make sure OS specific configuration is included first */
#include "dcmtk/oflog/loglevel.h"

#include "dcmtk/dcmdata/dcvrst.h"
#include "dcmtk/dcmdata/dcvrcs.h"
#include "dcmtk/dcmpstat/dvpsdef.h"
#include "dcmtk/dcmpstat/dvpstyp.h"

//#include "dcmtk/dcmdata/dcdatset.h"
//#include "dcmtk/ofstd/ofstd.h"
//#include "dcmtk/dcmdata/dctk.h"

//#define EXTRA_ERROR_REPORTING
#define OFFIS_CONSOLE_APPLICATION "printscu"

class AYDcmPrintSCU
{
  public:

    enum
    {
      NO_ERROR = 0,

      // configfile errors
      CONFIGFILE_NOT_DEFINED_ERROR,              // No configfile defined from calling application
      CONFIGFILE_NOT_FOUND_ERROR,                // The specified configfile does not exist
      CONFIGFILE_READ_ERROR,                     // The specified configfile could not be opened
      XML_PARSER_INITIALIZATION_ERROR,           // Error while initializing the xml library
      XML_PARSER_XML_ERROR,                      // Error while parsing the configfile

      // errors in connection parameters
      INVALID_HOST_ERROR,                        // The configured hostname or IP address was not valid
      INVALID_PORT_ERROR,                        // The configured port number was not valid
      INVALID_AETITLE_SENDER_ERROR,              // The configured AE title for the sender was not valid
      INVALID_AETITLE_RECEIVER_ERROR,            // The configured AE title for the receiver was not valid

      // missing general tags in configfile
      NO_ASSOCIATION_FOUND_ERROR,                // No association tag found in configfile
      NO_FILMSESSION_FOUND_ERROR,                // No film session tag found inside the association tag
      NO_FILMBOX_FOUND_ERROR,                    // No film box tag found inside the film session tag
      NO_IMAGEBOX_FOUND_ERROR,                   // No image box tags found inside the active film box

      // association errors
      OPEN_ASSOCIATION_ERROR,                    // There was an error during association negotiation
      CLOSE_ASSOCIATION_ERROR,                   // Error while closing the active association

      // film session specific errors
      FILMSESSION_CREATE_REQUEST_ERROR,          // Error while sending the N-CREATE request for film session
      REQUEST_MEMORY_ALLOCATION_FAILED,          // The SCP could not allocate the requested memory
      FILMSESSION_ACTION_REQUEST_ERROR,          // Error while sending the N-ACTION request for film session
      FILMSESSION_DELETE_REQUEST_ERROR,          // Error while sending the N-DELETE request for film session

      // film box specific errors
      NO_IMAGE_DISPLAY_FORMAT_ERROR,             // Attribute 'image display format' was not found in the processed film box
      FILMBOX_CREATE_REQUEST_ERROR,              // Error while sending the N-CREATE request for film box
      INVALID_SCP_RESPONSE,                      // The response from SCP has not the expected content
      FILMBOX_ACTION_REQUEST_ERROR,              // Error while sending the N-ACTION request for film box
      FILMBOX_DELETE_REQUEST_ERROR,              // Error while sending the N-DELETE request for film box

      // global errors
      NO_SUCH_ATTRIBUTE,                         // The SCP does not support at least one attribute in dataset
      INVALID_ATTRIBUTE_VALUE,                   // The SCP does not support the value for at least on attribute in dataset
      MISSING_ATTRIBUTE,                         // A mandatory attribute is missing in dataset
      UNSUPPORTED_ACTION_REQUEST,                // 
      RESOURCE_LIMITATION,                       //
      PRINT_QUEUE_FULL,                          //
      IMAGE_SIZE_TO_LARGE,                       //
      INSUFFICENT_MEMORY_ON_PRINTER,             //
      FILMSESSION_PRINTING_NOT_SUPPORTED,        //
      LAST_FILMBOX_NOT_PRINTED_YET,              //
      UNKNOWN_DIMSE_STATUS,                      //

        // errors while setting pixel data
        // from dicom file to image box
      INVALID_DICOM_FILE_PATH,
      READ_DICOM_FILE_ERROR,
      IMAGE_BOX_SET_REQUEST_ERROR,
      READ_ATTRIBUTE_ERROR,
      SET_ATTRIBUTE_ERROR
    };

    AYDcmPrintSCU(const char *hostname, int port, const char *aetitle, const char *aetitleSCU);

    ~AYDcmPrintSCU() {}

    /**
     * This is the main method which has to be called from a program to trigger the
     * print SCU.
     * @param images List of image files to be printed
     * @return Errorstatus
     */
    OFCondition sendPrintjob(std::list<std::string>& images);

  private:

    AYPrintManager *printHandler; // was m_pPrintManager

    // Association parameters
    std::string m_sHostname;
    int m_nPort;
    std::string m_sAETitleReceiver;
    std::string m_sAETitleSender;
    int m_nMaxPDUSize;
    bool m_bUseColorPrinting;
    bool m_bUseAnnotationBoxes;
    bool m_bUsePresentationLUT;
    bool m_bUseFilmSessionActionRequest;

    // Printer information
    std::string sPrinterStatus;
    std::string sPrinterStatusInfo;
    std::string sPrinterName;
    std::string Manufacturer;
    std::string ManufacturersModelName;
    std::string DeviceSerialNumber;
    std::string SoftwareVersion;
    std::string sDateOfLastCalibration;
    std::string sTimeOfLastCalibration;

    // Logging parameters
    std::string m_sLogpath;
    std::string m_sLogfileBasename;
    int m_nLoglevel;

    std::ostream *stdlogger;
    std::ostream *joblogger;
    std::ostream *dumplogger;

    std::ofstream *stdlogfile;
    std::ofstream *joblogfile;
    std::ofstream *dumplogfile;

    int closeAssociation();

    /**
     * Checks if a string value is an integer.
     * @param sValue String value to check.
     * @return true if sValue is an integer. false if not.
     */
    bool isInteger(std::string sValue);

    /**
     * Checks if a DICOM tag with key oKey is available in pDataset.
     * @param pDataset Pointer to a DICOM dataset which should be checked.
     * @param oKey Key of the attribute which should be searched.
     * @return true if attribute exists in pDataset, false otherwise.
     */
    bool isDicomAttributeAvailable(DcmDataset *pDataset, DcmTagKey oKey);

    /**
     * Searchs for an attribute with key oKey in pDataset and returns its value as a string.
     * @param pDataset Pointer to a DICOM dataset which contains the attribute.
     * @param oKey Key of the attribute which should be searched.
     * @return String containing the value of the attribute.
     */
    std::string getDicomAttributeValue(DcmDataset *pDataset, DcmTagKey oKey);

    /**
     * Searchs for an attribute with key oKey in DICOM dataset pDataset and the XML node pNode
     * and writes the found attribute to the DICOM item pItem. The value in pNote has a higher priority
     * than the value in pDataset. Optional attributes are added if they are available at least in one
     * of the sources. Missing mandatory attributes force an error if they don't exist in both sources.
     * @param pDataset Pointer to a DICOM dataset with information for this image box.
     * @param oKey Key of the attribute which should be searched and added.
     * @param pNode XML node with config information for this image box.
     * @param sAttrName Name of the attribute which should be searched and added.
     * @param pItem Pointer to the final DICOM object containing the new image box.
     * @param bIsMandatory Flag, which has to be set if the attribute is a mandatory attribute.
     * @return Error status. Possible values:
     *         - NO_ERROR
     *           No error occurred. Attribute has been successfully added or it was an
     *           optional attribute and not found in one of the sources.
     *         - SET_ATTRIBUTE_ERROR
     *           An error occurred while adding the attribute to the new item.
     *         - MISSING_ATTRIBUTE_ERROR
     *           The attribute was flaged as mandatory but not found in one of the sources
     */
    //int addImageBoxAttribute(DcmDataset *pDataset, DcmTagKey oKey, DOMNode *pNode, std::string sAttrName, DcmItem *pItem, bool bIsMandatory);


    /**
     * Returns a formatted string with the current date and time.
     * @return Formatted time string in the form YYYYMMDD.HHMMSS
     */
    std::string timestring(bool bAddSeparator=true);


    /**
     *
     */
    int decodeDimseStatus(unsigned int unStatus, std::string sRequest);

public:
    // dviface.hh 1803
    unsigned long printerNumberOfCopies;    // (2000,0010)
    OFString printerPriority;               // (2000,0020)
    OFString printerMediumType;             // (2000,0030)
    OFString printerFilmDestination;        // (2000,0040)
    OFString printerFilmSessionLabel;
    OFString printerOwnerID;
    OFString filmSessionInstanceUID;
    
    // dvpssp.h 1008
    DcmShortText imageDisplayFormat;
    DcmCodeString filmOrientation;      // (2010,0040)
    DcmCodeString filmSizeID;           // (2010,0050)
    DcmCodeString magnificationType;    // (2010,0060)
    DcmCodeString smoothingType;        // (2010,0080)
    DcmCodeString borderDensity;        // (2010,0100)
    DcmCodeString emptyImageDensity;    // (2010,0110)
    DcmCodeString trim;                 // (2010,0140)
    DcmShortText configurationInformation; // (2010,0150)
};

#endif
