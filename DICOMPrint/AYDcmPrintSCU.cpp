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

#include "AYDcmPrintSCU.h"

#include "dcmtk/dcmdata/dcdeftag.h"
#include "dcmtk/dcmdata/dcvris.h"
#include "dcmtk/dcmdata/dcvrlo.h"
#include "dcmtk/dcmdata/dcvrsh.h"
#include "dcmtk/dcmdata/dcvrui.h"
#include "dcmtk/dcmdata/dcvrus.h"
#include "dcmtk/dcmdata/dcsequen.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmsr/dsrtypes.h"
#include "dcmtk/ofstd/ofcmdln.h"

#define OFFIS_CONSOLE_APPLICATION "printscu"

static OFLogger printscuLogger = OFLog::getLogger("dcmtk.apps." OFFIS_CONSOLE_APPLICATION);

// See DCMTK storescu.cc line 1314
static OFString
intToString(int i)
{
    char numbuf[32];
    sprintf(numbuf, "%d", i);
    return numbuf;
}

// See DCMTK storescu.cc line 1322
// See GingkoCAD ginkgouid.cpp line 29
static OFString
makeUID(OFString basePrefix, int counter)
{
    OFString prefix = basePrefix + "." + intToString(counter);
    char uidbuf[65];
    OFString uid = dcmGenerateUniqueIdentifier(uidbuf, prefix.c_str());
    return uid;
}

// /////////////////////////////////////////////////////////////////////////////
AYDcmPrintSCU::AYDcmPrintSCU(const char *hostnameSCP, int portSCP, const char *aetitleSCP, const char *aetitleSCU)
: imageDisplayFormat(DCM_ImageDisplayFormat)
, filmOrientation(DCM_FilmOrientation)
, filmSizeID(DCM_FilmSizeID)
, magnificationType(DCM_MagnificationType)
, smoothingType(DCM_SmoothingType)
, borderDensity(DCM_BorderDensity)
, emptyImageDensity(DCM_EmptyImageDensity)
, trim(DCM_Trim)
, configurationInformation(DCM_ConfigurationInformation)
, m_sHostname(hostnameSCP)
, m_nPort(portSCP)
, m_sAETitleReceiver(aetitleSCP)
, m_sAETitleSender(aetitleSCU)
, printHandler(NULL)
{
#ifndef NDEBUG
    OFLog::configure(OFLogger::DEBUG_LOG_LEVEL);
#endif
}

// See GingkoCAD dicomprintassociation.cpp line 192 PrintAssociation::Print()
OFCondition AYDcmPrintSCU::sendPrintjob(std::list<std::string>& images)
{
    OFCondition cond;
    
    if (printHandler==NULL) {
        OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__ << " null printHandler");
        printHandler = new AYPrintManager;
    }

#pragma mark - 1. Open Association

    DcmTransportLayer *tlayer = NULL;
    unsigned long targetMaxPDU      = ASC_DEFAULTMAXPDU;
    OFBool targetSupportsPLUT       = OFTrue;   // TODO:
    OFBool targetSupportsAnnotation = OFTrue;   // TODO:
    OFBool negotiateColorjob        = OFFalse;
    OFBool targetImplicitOnly       = OFFalse;

    cond = printHandler->negotiateAssociation(
        tlayer,
        m_sAETitleSender.c_str(),
        m_sAETitleReceiver.c_str(),
        m_sHostname.c_str(),
        m_nPort,
        targetMaxPDU,
        targetSupportsPLUT,
        targetSupportsAnnotation,
        negotiateColorjob,
        targetImplicitOnly);

    if (cond.bad())
    {
        OFLOG_ERROR(printscuLogger, "Connection Error:" << cond.text());
        return cond;
    }

#pragma mark - 2. N-GET (Printer)

    Uint16 rstatus;
    
    DcmDataset* response;
    DcmDataset attrs;
    DcmElement* e = NULL;
    DcmSequenceOfItems* seq = NULL;
    DcmItem* item = NULL;

    Uint16 *infoAttrList = NULL;

    // See DCMTK dvpssp.cc line 1249 DVPSStorePrint::printSCUgetPrinterInstance()
    // See GingkoCAD dicomprintassociation.cpp line 230 PrintAssociation::Print()
    cond = printHandler->getRQ( UID_PrinterSOPClass, UID_PrinterSOPInstance, infoAttrList, 0, rstatus, response);
    if (cond.bad()) {
        OFLOG_ERROR(printscuLogger, __FUNCTION__ << __LINE__ << cond.text());
        return cond;
    }

#pragma mark - 3. N-CREATE (Presentation LUT)
    // TODO:

#pragma mark - 4. N-CREATE (Film Session)

    delete response;
    response = NULL;
    attrs.clear();
    
    // (2000, 0010)
    char buf[20];
    sprintf(buf, "%lu", printerNumberOfCopies);
    e = new DcmIntegerString(DCM_NumberOfCopies);
    e->putString(buf);
    attrs.insert(e);
    
    // (2000,0020)
    e = new DcmCodeString(DCM_PrintPriority);
    e->putString(printerPriority.c_str());
    attrs.insert(e);

    // (2000,0030)
    e = new DcmCodeString(DCM_MediumType);
    e->putString(printerMediumType.c_str());
    attrs.insert(e);

    // (2000,0040)
    e = new DcmCodeString(DCM_FilmDestination);
    e->putString(printerFilmDestination.c_str());
    attrs.insert(e);

    // (2000,0050)
    OFString tmpString;
    DSRTypes::currentDateTime(tmpString);
    OFString label = "print job Miele-LXIV created " + tmpString;
    // See DCMTK dviface.cc line 3854 DVInterface::printSCUcreateBasicFilmSession()
    // See GingkoCAD dicomprintassociation.cpp line 277 PrintAssociation::Print()
    e = new DcmLongString(DCM_FilmSessionLabel);
    e->putString(printerFilmSessionLabel.c_str());
    attrs.insert(e);

    e = new DcmShortString(DCM_OwnerID);
    e->putString(printerOwnerID.c_str());
    attrs.insert(e);

    OFCmdUnsignedInt imageCounter = 0;
    filmSessionInstanceUID = makeUID(SITE_INSTANCE_UID_ROOT, OFstatic_cast(int, imageCounter));
    // See DCMTK dvpssp.cc line 1432 DVPSStoredPrint::printSCUcreateBasicFilmSession()
    // See GingkoCAD dicomprintassociation.cpp line 297 PrintAssociation::Print()
    cond = printHandler->createRQ(UID_BasicFilmSessionSOPClass, filmSessionInstanceUID, &attrs, rstatus, response);
    if (cond.bad()) {
        OFLOG_ERROR(printscuLogger, __FUNCTION__ << __LINE__ << cond.text());
        return cond;
    }
    
#pragma mark - 5. N-CREATE (Film Box)

    delete response;
    response = NULL;
    attrs.clear();
    
    // (2010, 0010)
    e = new DcmShortText(imageDisplayFormat);
    attrs.insert(e);
    
    // (2010,0500)
    {
        seq = new DcmSequenceOfItems(DCM_ReferencedFilmSessionSequence);
        item = new DcmItem();
        
        // (0008,1150)
        e = new DcmUniqueIdentifier(DCM_ReferencedSOPClassUID);
        e->putString(UID_BasicFilmSessionSOPClass);
        item->insert(e);
        
        // (0008,1155)
        e = new DcmUniqueIdentifier(DCM_ReferencedSOPInstanceUID);
        e->putString(filmSessionInstanceUID.c_str());
        
        item->insert(e);
        seq->insert(item);
        
        attrs.insert(seq);
    }
    
    // (2010,0040)
    e = new DcmCodeString(filmOrientation);
    attrs.insert(e);
    
    // (2010,0050)
    e = new DcmCodeString(filmOrientation);
    attrs.insert(e);
    
    // (2010,0060)
    if (magnificationType.getLength() > 0) {
        e = new DcmCodeString(magnificationType);
        attrs.insert(e);
    }
    
    // (2010,0080)
    if (smoothingType.getLength() > 0) {
        e = new DcmCodeString(smoothingType);
        attrs.insert(e);
    }
    
    // (2010,0100)
    e = new DcmCodeString(borderDensity);
    attrs.insert(e);
    
    // (2010,0110)
    e = new DcmCodeString(emptyImageDensity);
    attrs.insert(e);
    
#if 0
    // (2010,0120)
    DcmUnsignedShort minDensity(DCM_MinDensity);
    Uint16 density = 0;
    minDensity.putUint16(density, 0);
    minDensity.clear();
    
    // (2010,0130)
    DcmUnsignedShort maxDensity(DCM_MaxDensity);
    //Uint16 density = 0;
    maxDensity.putUint16(density, 0);
    maxDensity.clear();
#endif
    
    // (2010,0140)
    if (trim.getLength() > 0) {
        e = new DcmCodeString(trim);
        attrs.insert(e);
    }

    OFString filmBoxSOPInstanceUID;
    // See DCMTK dvpssp.cc line 1519 DVPSStoredPrint::printSCUcreateBasicFilmBox()
    // See GingkoCAD dicomprintassociation.cpp line 391 PrintAssociation::Print()
    cond = printHandler->createRQ(UID_BasicFilmBoxSOPClass, filmBoxSOPInstanceUID, &attrs, rstatus, response);
    if (cond.bad()) {
        OFLOG_ERROR(printscuLogger, __FUNCTION__ << __LINE__ << cond.text());
        return cond;
    }

    // N-CREATE was successful, now evaluate Referenced Image Box SQ
    DcmSequenceOfItems* referencedImageBoxSequence = NULL;
    // (2010,0510)
    response->findAndGetSequence(DCM_ReferencedImageBoxSequence, referencedImageBoxSequence, false, false);
    // Note: DCMTK uses search() instead of findAndGetSequence()
    
    // (0008,1150)
    referencedImageBoxSequence->getItem(0)->findAndGetElement(DCM_ReferencedSOPClassUID, e, false, false);
    
    std::string referencedImageBoxSOPClass;
    {
        char* sopClassUID = NULL;
        if (e->getString(sopClassUID).bad()) {
            OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
            return makeOFCondition(OFM_dcmnet, 16, OF_error, "No Image Box SOP Class received");
        }
        referencedImageBoxSOPClass = sopClassUID;
    }
    
#if 0 // TODO Color
    if (referencedImageBoxSOPClass != UID_BasicColorImageBoxSOPClass) {
        OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
        return makeOFCondition(OFM_dcmnet, 16, OF_error, "Invalid Image Box SOP Class for color print");
    }
#else
    if (referencedImageBoxSOPClass != UID_BasicGrayscaleImageBoxSOPClass) {
        OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
        return makeOFCondition(OFM_dcmnet, 16, OF_error, "Invalid Image Box SOP Class for grayscale print");
    }
#endif

    // (0008,1155)
    if (referencedImageBoxSequence->getItem(0)->findAndGetElement(DCM_ReferencedSOPInstanceUID, e, false, false).bad()) {
        OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
        return makeOFCondition(OFM_dcmnet, 16, OF_error, "No Image Box SOP Instance UID received");
    }

    std::string referencedImageBoxSOPInstanceUID;
    {
        char * sopInstanceUID = NULL;
        if (e->getString(sopInstanceUID).bad()) {
            OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
            return makeOFCondition(OFM_dcmnet, 16, OF_error, "Invalid Image Box SOP Instance UID received");
        }
        referencedImageBoxSOPInstanceUID = sopInstanceUID;
        //const char* test1 = referencedImageBoxSOPInstanceUID.c_str();
        //const char* test2 = sopInstanceUID;
    }
#ifndef NDEBUG
    std::cout << "Ref SOP = " << referencedImageBoxSOPInstanceUID << std::endl;
#endif

#pragma mark - 6. N-SET (Image Box)
    
    unsigned int pos = 1;
    for (std::list<std::string>::const_iterator it = images.begin(); it != images.end(); ++it, pos++) {
        
        delete response;
        response = NULL;
        attrs.clear();
        
        const std::string& filePath = (*it);
        
        DcmFileFormat ff;
        DcmDataset* ds = NULL;
        
        // 456
        cond = ff.loadFile(filePath.c_str(), EXS_Unknown, EGL_noChange, DCM_MaxReadLength, ERM_autoDetect);
        
//        std::string outfname;
//        {
//            std::ostringstream os;
//            os << GNC::Entorno::Instance()->GetGinkgoTempDir().c_str() << (char) wxFileName::GetPathSeparator(wxPATH_NATIVE) << "print_slice_" << pos << ".dcm";
//            outfname = os.str();
//        }
        
        DcmXfer filexfer(ff.getDataset()->getOriginalXfer());
        
        if (filexfer.getXfer() == EXS_JPEG2000LosslessOnly ||
            filexfer.getXfer() == EXS_JPEG2000)
        {
            OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
#if 0
            if (!DecompressJPEG2000(filePath, outfname)) {
                
                return makeOFCondition(OFM_dcmdata, 16, OF_error, "Unable to decompress JPEG2000");
            }
            
            //OFLOG_WARN(printscuLogger, "The file is being uncompressed from JPG2000. Some tags could be lost");
            ff.loadFile(outfname.c_str(), EXS_Unknown, EGL_noChange, DCM_MaxReadLength, ERM_autoDetect);
#endif
        }
        
        ff.getDataset()->chooseRepresentation(EXS_LittleEndianExplicit, NULL);
        
        // check if everything went well
        if (ff.getDataset()->canWriteXfer(EXS_LittleEndianExplicit))
        {
            ff.loadAllDataIntoMemory();
//            unlink(outfname.c_str());
//            cond = ff.saveFile( outfname.c_str(), EXS_LittleEndianExplicit);
        }
        else {
            OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
            return makeOFCondition(OFM_dcmdata, 16, OF_error, "Unable to convert to LittleEndianExplicit");
        }
        
        // 492
        if (cond.bad()) {
            OFLOG_ERROR(printscuLogger, __FUNCTION__ << __LINE__ << cond.text());
            return cond;
        }

        ds = ff.getDataset();
        OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
        //ds->print(std::cout); // it also prints all the pixel data

        cond = attrs.chooseRepresentation(ff.getDataset()->getOriginalXfer(), NULL);
        if (cond.bad()) {
            OFLOG_ERROR(printscuLogger, __FUNCTION__ << __LINE__ << cond.text());
            return makeOFCondition(OFM_dcmdata, 16, OF_error, "Unable to choose LittleEndianExplicit representation");
        }

        e = new DcmUnsignedShort(DCM_ImageBoxPosition);
        e->putUint16(pos);
        attrs.insert(e);
        
#if 0 // TODO
        seq = new DcmSequenceOfItems(DCM_BasicColorImageSequence);
#else
        seq = new DcmSequenceOfItems(DCM_BasicGrayscaleImageSequence);
#endif
        
        item = new DcmItem();
        
        // (0028,0002)
        OFBool searchIntoSub = OFTrue;
        OFBool createCopy = OFTrue;

        if (ds->findAndGetElement(DCM_SamplesPerPixel, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_PhotometricInterpretation, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_Rows, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_Columns, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_PixelAspectRatio, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_BitsAllocated, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_BitsStored, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_HighBit, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_PixelRepresentation, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        if (ds->findAndGetElement(DCM_PixelData, e, searchIntoSub, createCopy).good()) {
            item->insert(e);
        }
        
        seq->insert(item);
        attrs.insert(seq);
        //c = attrs.chooseRepresentation(EXS_LittleEndianExplicit, NULL);
        //attrs.insertEmptyElement(DCM_TransferSyntaxUID, EXS_LittleEndianExplicit);
        
        cond = printHandler->setRQ(referencedImageBoxSOPClass.c_str(),
                                   referencedImageBoxSOPInstanceUID.c_str(),
                                   &attrs,
                                   rstatus,
                                   response);
        
        if (cond.bad()) {
            OFLOG_ERROR(printscuLogger, __FUNCTION__ << __LINE__ << cond.text());
            return cond;
        }
    } // for 6.
    
#pragma mark - 7. N-ACTION (Film Box)

    delete response;
    response = NULL;
    attrs.clear();
    
    // 577
    OFCondition resultStatus = printHandler->actionRQ(UID_BasicFilmBoxSOPClass,
                                                      filmBoxSOPInstanceUID.c_str(),
                                                      1,
                                                      NULL,
                                                      rstatus,
                                                      response);
    
#pragma mark - 8. N-DELETE (Film Box)

    if (filmBoxSOPInstanceUID.size() > 0) {
        OFLOG_DEBUG(printscuLogger, __FUNCTION__ << __LINE__);
        // See DCMTK dvpssp.cc line 1612 DVPSStoredPrint::printSCUdelete()
        cond = printHandler->deleteRQ(UID_BasicFilmBoxSOPClass, filmBoxSOPInstanceUID.c_str(), rstatus);
        filmBoxSOPInstanceUID.clear();
    }
    
#pragma mark - 9. N-DELETE (Film Session)

    if (filmSessionInstanceUID.size() > 0) {
        cond = printHandler->deleteRQ(UID_BasicFilmSessionSOPClass, filmSessionInstanceUID.c_str(), rstatus);
        filmSessionInstanceUID.clear();
    }

#pragma mark - 10. N-DELETE (Presentation LUT)
    
//    if (presentationLUTInstanceUID.size() > 0) {
//        cond = printHandler->deleteRQ(UID_PresentationLUTSOPClass, presentationLUTInstanceUID.c_str(), rstatus);
//        presentationLUTInstanceUID.clear();
//    }

    //return resultStatus;

    if (cond.bad())
        OFLOG_ERROR(printscuLogger, "Error sending object:" << cond.text());

#pragma mark - 11. Close Association
    cond = printHandler->releaseAssociation();
    OFLOG_TRACE(printscuLogger, __FUNCTION__ << __LINE__);

    return cond;
}
