//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#undef verify
#include "dcmtk/config/osconfig.h"    /* make sure OS specific configuration is included first */

#import "BrowserController.h"
#import "DICOMToNSString.h"
#import "LogManager.h"
#import "DICOMFiles/dicomFile.h"


BEGIN_EXTERN_C
#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif
#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif
#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
END_EXTERN_C

#define INCLUDE_CCTYPE
#define INCLUDE_CSTDARG
#define INCLUDE_CTIME
#include "dcmtk/ofstd/ofstdinc.h"

#include "dcmtk/dcmqrdb/dcmqrdbs.h"
// #include "dcmtk/dcmqrdb/dcmqrdbi.h"
#include "dcmtk/dcmqrdb/dcmqrcnf.h"

#include "dcmtk/dcmqrdb/dcmqridx.h"
#include "dcmtk/dcmnet/diutil.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/ofstd/ofstd.h"

#ifdef WITH_SQL_DATABASE
#include "dcmtk/dcmqrdbx/dcmqrdbq.h"
#else
//#include "dcmtk/dcmqrdb/dcmqrdbi.h"
#include "dcmqrdbq.h" // glue/dcmqrdb
#endif

#include "dcmtk/ofstd/ofstring.h"
#include "dcmtk/dcmnet/dimse.h"
#include "dcmtk/dcmdata/dcdatset.h"
#include "dcmtk/dcmdata/dcmetinf.h"
#include "dcmtk/dcmdata/dcuid.h"
#include "dcmtk/dcmdata/dcdict.h"
#include "dcmtk/dcmdata/dcdeftag.h"

#include "dcmtk/ofstd/ofconapp.h"
#include "dcmtk/dcmnet/dicom.h"     /* for DICOM_APPLICATION_REQUESTOR */
#include "dcmtk/dcmdata/dcostrmz.h"  /* for dcmZlibCompressionLevel */
#include "dcmtk/dcmnet/dcasccfg.h"  /* for class DcmAssociationConfiguration */
#include "dcmtk/dcmnet/dcasccff.h"  /* for class DcmAssociationConfigurationFile */

#include "dcmtk/dcmjpeg/djdecode.h"  /* for dcmjpeg decoders */
#include "dcmtk/dcmjpeg/djencode.h"  /* for dcmjpeg encoders */
#include "dcmtk/dcmdata/dcrledrg.h"  /* for DcmRLEDecoderRegistration */
#include "dcmtk/dcmdata/dcrleerg.h"  /* for DcmRLEEncoderRegistration */
#include "dcmtk/dcmjpeg/djrploss.h"
#include "dcmtk/dcmjpeg/djrplol.h"
#include "dcmtk/dcmdata/dcpixel.h"
#include "dcmtk/dcmdata/dcrlerp.h"

#include "dcmtk/dcmdata/dcerror.h"

//#define HANDLE_QUERY_IDENTIFIER
#define NUM_ENCODINGS        10

extern BOOL forkedProcess;

// See DCMTK sources: dcmqropt.cc
const OFCondition DcmQROsiriXDatabaseError(OFM_dcmqrdb, 1, OF_error, "DcmQR Index Database Error");

#pragma mark - See DCMTK's dcmqrdbi.cc

#pragma mark - static data

/* ========================= static data ========================= */

/**** The TbFindAttr table contains the description of tags (keys) supported
 **** by the DB Module.
 **** Tags described here have to be present in the Index Record file.
 **** The order is insignificant.
 ****
 **** Each element of this table is described by
 ****           The tag value
 ****           The level of this tag (from patient to image)
 ****           The Key Type (only UNIQUE_KEY values is used)
 ****
 **** This table and the IndexRecord structure should contain at least
 **** all Unique and Required keys.
 ***/

static const DB_FindAttr TbFindAttr [] = {
    DB_FindAttr( DCM_PatientBirthDate ,                    PATIENT_LEVEL,  OPTIONAL_KEY ),
    DB_FindAttr( DCM_PatientSex,                           PATIENT_LEVEL,  OPTIONAL_KEY ),
    DB_FindAttr( DCM_PatientName,                          PATIENT_LEVEL,  REQUIRED_KEY ),
    DB_FindAttr( DCM_PatientID,                            PATIENT_LEVEL,  UNIQUE_KEY   ),
    DB_FindAttr( DCM_PatientBirthTime,                     PATIENT_LEVEL,  OPTIONAL_KEY ),

    DB_FindAttr( DCM_RETIRED_OtherPatientIDs,               PATIENT_LEVEL,  OPTIONAL_KEY ),
    DB_FindAttr( DCM_OtherPatientNames,                     PATIENT_LEVEL,  OPTIONAL_KEY ),
    DB_FindAttr( DCM_EthnicGroup,                           PATIENT_LEVEL,  OPTIONAL_KEY ),
    DB_FindAttr( DCM_PatientComments,                       PATIENT_LEVEL,  OPTIONAL_KEY ),
    DB_FindAttr( DCM_IssuerOfPatientID,                     PATIENT_LEVEL,  OPTIONAL_KEY ),
//    DB_FindAttr( DCM_NumberOfPatientRelatedStudies,         PATIENT_LEVEL,  OPTIONAL_KEY ),
//    DB_FindAttr( DCM_NumberOfPatientRelatedSeries,          PATIENT_LEVEL,  OPTIONAL_KEY ),
//    DB_FindAttr( DCM_NumberOfPatientRelatedInstances,       PATIENT_LEVEL,  OPTIONAL_KEY ),

    DB_FindAttr( DCM_StudyDate,                             STUDY_LEVEL,    REQUIRED_KEY ),
    DB_FindAttr( DCM_StudyTime,                             STUDY_LEVEL,    REQUIRED_KEY ),
    DB_FindAttr( DCM_StudyID,                               STUDY_LEVEL,    REQUIRED_KEY ),
    DB_FindAttr( DCM_AccessionNumber,                       STUDY_LEVEL,    REQUIRED_KEY ),
    DB_FindAttr( DCM_ReferringPhysicianName,                STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_StudyDescription,                      STUDY_LEVEL,    OPTIONAL_KEY ),

    DB_FindAttr( DCM_NameOfPhysiciansReadingStudy,          STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_StudyInstanceUID,                      STUDY_LEVEL,    UNIQUE_KEY   ),

    DB_FindAttr( DCM_RETIRED_OtherStudyNumbers,             STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_AdmittingDiagnosesDescription,         STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_PatientAge,                            STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_PatientSize,                           STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_PatientWeight,                         STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_Occupation,                            STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_AdditionalPatientHistory,              STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_NumberOfStudyRelatedSeries,            STUDY_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_NumberOfStudyRelatedInstances,         STUDY_LEVEL,    OPTIONAL_KEY ),

    DB_FindAttr( DCM_SeriesNumber,                          SERIE_LEVEL,    REQUIRED_KEY ),
    DB_FindAttr( DCM_SeriesInstanceUID,                     SERIE_LEVEL,    UNIQUE_KEY   ),
    DB_FindAttr( DCM_Modality,                              SERIE_LEVEL,    OPTIONAL_KEY ),
    DB_FindAttr( DCM_InstanceNumber,                        IMAGE_LEVEL,    REQUIRED_KEY ),
    DB_FindAttr( DCM_SOPInstanceUID,                        IMAGE_LEVEL,    UNIQUE_KEY   )
  };

/**** The NbFindAttr variable contains the length of the TbFindAttr table
 ***/

static int NbFindAttr = ((sizeof (TbFindAttr)) / (sizeof (TbFindAttr [0])));


OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::pruneInvalidRecords()
{
    return (EC_Normal) ;
}

/***********************
 *    Free an element List
 */

static OFCondition DB_FreeUidList (DB_UidList *lst)
{
    while (lst != NULL) {
        if (lst -> patient)
            free (lst -> patient);
        if (lst -> study)
            free (lst -> study);
        if (lst -> serie)
            free (lst -> serie);
        if (lst -> image)
            free (lst -> image);
        DB_UidList *curlst = lst;
        lst = lst->next;
        free (curlst);
    }
    return EC_Normal;
}

/*******************
 *    Free a UID List
 */

static OFCondition DB_FreeElementList (DB_ElementList *lst)
{
    if (lst == NULL) return EC_Normal;

    OFCondition cond = DB_FreeElementList (lst -> next);
    if (lst->elem.PValueField != NULL) {
        free ((char *) lst -> elem. PValueField);
    }
    delete lst;
    return (cond);
}

/*******************
 *    Is the specified tag supported
 */

static int DB_TagSupported (DcmTagKey tag)
{
    int i;

    for (i = 0; i < NbFindAttr; i++)
        if (TbFindAttr[i]. tag == tag)
            return (OFTrue);

    return (OFFalse);

}

/*******************
 *    Get UID tag of a specified level
 */

#if 0
static OFCondition DB_GetUIDTag (DB_LEVEL level, DcmTagKey *tag)
{
    int i;
    for (i = 0; i < NbFindAttr; i++)
    if ((TbFindAttr[i]. level == level) && (TbFindAttr[i]. keyAttr == UNIQUE_KEY))
        break;

    if (i < NbFindAttr) {
        *tag = TbFindAttr[i].tag;
        return (EC_Normal);
    }
    else
    return (DcmQROsiriXDatabaseError);

}
#endif

/*******************
 *    Get tag level of a specified tag
 */

static OFCondition DB_GetTagLevel (DcmTagKey tag, DB_LEVEL *level)
{
    int i;

    for (i = 0; i < NbFindAttr; i++)
        if (TbFindAttr[i]. tag == tag)
            break;

    if (i < NbFindAttr) {
        *level = TbFindAttr[i]. level;
        return (EC_Normal);
    }
    
    return (DcmQROsiriXDatabaseError);
}

/*******************
 *    Get tag key attribute of a specified tag
 */

static OFCondition DB_GetTagKeyAttr (DcmTagKey tag, DB_KEY_TYPE *keyAttr)
{
    int i;

    for (i = 0; i < NbFindAttr; i++)
        if (TbFindAttr[i]. tag == tag)
            break;

    if (i < NbFindAttr) {
        *keyAttr = TbFindAttr[i]. keyAttr;
        return (EC_Normal);
    }
    else
    return (DcmQROsiriXDatabaseError);
}

/*******************
 *    Get tag key attribute of a specified tag
 */

//static OFCondition DB_GetTagKeyClass (DcmTagKey tag, DB_KEY_CLASS *keyAttr)
//{
//    int ii;
//
//    for (ii = 0; ii < NbFindAttr; ii++)
//    if (TbFindAttr[ii]. tag == tag)
//        break;
//
//    if (ii < NbFindAttr) {
//    *keyAttr = TbFindAttr[ii]. keyClass;
//    return (EC_Normal);
//    }
//    else
//    return (DcmQROsiriXDatabaseError);
//}

/***********************
 *    Duplicate a DICOM element
 *    dst space is supposed provided by the caller
 */

#ifdef HANDLE_QUERY_IDENTIFIER
static void DB_DuplicateElement (DB_SmallDcmElmt *src, DB_SmallDcmElmt *dst)
{
    bzero( (char*)dst, sizeof (DB_SmallDcmElmt));
    dst -> XTag = src -> XTag;
    dst -> ValueLength = src -> ValueLength;

    if (src -> ValueLength == 0)
        dst -> PValueField = NULL;
    else {
        dst -> PValueField = (char *)malloc ((int) src -> ValueLength+1);
        bzero(dst->PValueField, (size_t)(src->ValueLength+1));
        if (dst->PValueField != NULL) {
            memcpy (dst -> PValueField,  src -> PValueField,
                (size_t) src -> ValueLength);
        } else {
            DCMQRDB_ERROR("DB_DuplicateElement: out of memory");
        }
    }
}
#endif

void str_toupper(char *s)
{
    while(*s)
    {
		int v = toupper(*s);
		if (v < 32) v = '0';
		if (v > 'Z') v = '0';
        *s = v;
        s++;
    }
}

#pragma mark -

/*************
Log Entry
*************/
OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::updateLogEntry(DcmDataset *dataset)
{
	if ([[BrowserController currentBrowser] isNetworkLogsActive] == NO)
        return EC_Normal;
	
	const char *scs = 0L;
	const char *pn = 0L;
	const char *sd = 0L;
	const char *sss = 0L;
	char patientName[ 1024];
	char studyDescription[ 1024];
	char seriesUID[ 1024];
	char specificCharacterSet[ 1024];
	
	// ************

	if (dataset->findAndGetString (DCM_SpecificCharacterSet, scs, OFFalse).good() && scs != NULL)
	{
		strcpy( specificCharacterSet, scs);
	}
	else
	{
		strcpy( specificCharacterSet, "ISO_IR 100");
	}
	
	if (dataset->findAndGetString (DCM_PatientName, pn, OFFalse).good() && pn != NULL)
	{
		strcpy( patientName, pn);
	}
	else
	{
		strcpy( patientName, "");
	}
    	
	if (dataset->findAndGetString (DCM_StudyDescription, sd, OFFalse).good() && sd != NULL)
	{
		strcpy( studyDescription, sd);
	}
	else
	{
		strcpy( studyDescription, "");
	}
	
	if (dataset->findAndGetString (DCM_SeriesDescription, sss, OFFalse).good() && sss != NULL)
	{
		strcat( studyDescription, " ");
		strcat( studyDescription, sss);
	}
	
	if (dataset->findAndGetString (DCM_SeriesInstanceUID, sss, OFFalse).good() && sss != NULL)
		strcpy( seriesUID, sss);
	else
        strcpy( seriesUID, patientName);
	
	if (handle_->logDictionary == nil)
	{
		handle_->logDictionary = [NSMutableDictionary new];
		
        // Encoding
        NSStringEncoding myEncodings[NUM_ENCODINGS];
        myEncodings[0] = NSISOLatin1StringEncoding;
        for (int i = 1; i < NUM_ENCODINGS; i++)
            myEncodings[i] = NSUTF8StringEncoding;
        
        NSArray	*c = [[NSString stringWithCString: specificCharacterSet] componentsSeparatedByString:@"\\"];
        
        if ([c count] < NUM_ENCODINGS)
        {
            for (int i = 0; i < [c count]; i++)
                myEncodings[ i] = [NSString encodingForDICOMCharacterSet: [c objectAtIndex: i]];
        }
        
        [handle_->logDictionary setObject: [DicomFile stringWithBytes: patientName encodings: myEncodings] forKey: @"logPatientName"];
        [handle_->logDictionary setObject: [DicomFile stringWithBytes: studyDescription encodings: myEncodings] forKey: @"logStudyDescription"];
        [handle_->logDictionary setObject: handle_->callingAET forKey: @"logCallingAET"];
        [handle_->logDictionary setObject: [NSDate date] forKey: @"logStartTime"];
		[handle_->logDictionary setObject: @"In Progress" forKey: @"logMessage"];
        [handle_->logDictionary setObject: @"Receive" forKey: @"logType"];
        
		unsigned int random = (unsigned int)time(NULL);
		unsigned int random2 = rand();
		[handle_->logDictionary setObject: [NSString stringWithFormat: @"%d%d%@%s", random, random2, [handle_->logDictionary objectForKey: @"logPatientName"], seriesUID] forKey: @"logUID"];
	}
	
	[handle_->logDictionary setObject: [NSNumber numberWithInt: ++(handle_->imageCount)] forKey: @"logNumberReceived"];
    [handle_->logDictionary setObject: [handle_->logDictionary objectForKey: @"logNumberReceived"] forKey: @"logNumberTotal"];
	[handle_->logDictionary setObject: [NSDate date] forKey: @"logEndTime"];
	
    [[LogManager currentLogManager] addLogLine: handle_->logDictionary];
    
	return EC_Normal;
}

#pragma mark - FIND

/* ========================= FIND ========================= */

// See DCMTK sources: dcmqrdbi.cc:1057

/************
**      Test a Find Request List
**      Returns EC_Normal if OK, else returns DcmQROsiriXDatabaseError
 */

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::testFindRequestList (
                DB_ElementList  *findRequestList,
                DB_LEVEL        queryLevel,
                DB_LEVEL        infLevel,
                DB_LEVEL        lowestLevel
                )
{
    DB_ElementList *plist ;
    DB_LEVEL    XTagLevel = PATIENT_LEVEL; // DB_GetTagLevel() will set this correctly
    DB_KEY_TYPE XTagType  = OPTIONAL_KEY;  // DB_GetTagKeyAttr() will set this
    int level ;

    /**** Query level must be at least the infLevel
    ***/

    if ((queryLevel < infLevel) ||
        (queryLevel > lowestLevel))
    {
        DCMQRDB_INFO("Level incompatible with Information Model (level " << queryLevel << ")");
        return DcmQROsiriXDatabaseError ;
    }

    for (level = PATIENT_LEVEL ; level <= IMAGE_LEVEL ; level++) {

        /**** Manage exception due to StudyRoot Information Model :
        **** In this information model, queries may include Patient attributes
        **** but only if they are made at the study level
        ***/

        if ((level == PATIENT_LEVEL) && (infLevel == STUDY_LEVEL)) {
            /** In Study Root Information Model, accept only Patient Tags
            ** if the Query Level is the Study level
            */

            int atLeastOneKeyFound = OFFalse ;
            for (plist = findRequestList ; plist ; plist = plist->next) {
                DB_GetTagLevel (plist->elem. XTag, &XTagLevel) ;
                if (XTagLevel != level)
                    continue ;
                atLeastOneKeyFound = OFTrue ;
            }
            if (atLeastOneKeyFound && (queryLevel != STUDY_LEVEL)) {
                DCMQRDB_DEBUG("Key found in Study Root Information Model (level " << level << ")");
                return DcmQROsiriXDatabaseError ;
            }
        }

        /**** If current level is above the QueryLevel
        ***/

        else if (level < queryLevel) {

            /** For this level, only unique keys are allowed
            ** Parse the request list elements referring to
            ** this level.
            ** Check that only unique key attr are provided
            */

            int uniqueKeyFound = OFFalse ;
            for (plist = findRequestList ; plist ; plist = plist->next) {
                DB_GetTagLevel (plist->elem. XTag, &XTagLevel) ;
                if (XTagLevel != level)
                    continue ;
                DB_GetTagKeyAttr (plist->elem. XTag, &XTagType) ;
                if (XTagType != UNIQUE_KEY) {
                    DCMQRDB_DEBUG("Non Unique Key found (level " << level << ")");
                    return DcmQROsiriXDatabaseError ;
                }
                else if (uniqueKeyFound) {
                    DCMQRDB_DEBUG("More than one Unique Key found (level " << level << ")");
                    return DcmQROsiriXDatabaseError ;
                }
                else
                    uniqueKeyFound = OFTrue ;
            }
        }

        /**** If current level is the QueryLevel
        ***/

        else if (level == queryLevel) {

            /** For this level, all keys are allowed
            ** Parse the request list elements referring to
            ** this level.
            ** Check that at least one key is provided
            */

            int atLeastOneKeyFound = OFFalse ;
            for (plist = findRequestList ; plist ; plist = plist->next) {
                DB_GetTagLevel (plist->elem. XTag, &XTagLevel) ;
                if (XTagLevel != level)
                    continue ;
                atLeastOneKeyFound = OFTrue ;
            }
            if (! atLeastOneKeyFound) {
                DCMQRDB_DEBUG("No Key found at query level (level " << level << ")");
                return DcmQROsiriXDatabaseError ;
            }
        }

        /**** If current level beyond the QueryLevel
        ***/

        else if (level > queryLevel) {

            /** For this level, no key is allowed
            ** Parse the request list elements referring to
            ** this level.
            ** Check that no key is provided
            */

            int atLeastOneKeyFound = OFFalse ;
            for (plist = findRequestList ; plist ; plist = plist->next) {
                DB_GetTagLevel (plist->elem. XTag, &XTagLevel) ;
                if (XTagLevel != level)
                    continue ;
                atLeastOneKeyFound = OFTrue ;
            }
            if (atLeastOneKeyFound) {
                DCMQRDB_DEBUG("Key found beyond query level (level " << level << ")");
                return DcmQROsiriXDatabaseError ;
            }
        }
    }
    return EC_Normal ;
}

/********************
**      Start find in Database
**/

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::startFindRequest(
                const char      *SOPClassUID,
                DcmDataset      *findRequestIdentifiers,
                DcmQueryRetrieveDatabaseStatus  *status)
{
    DB_SmallDcmElmt     elem ;
#ifdef HANDLE_QUERY_IDENTIFIER
    DB_ElementList      *plist = NULL;
    DB_ElementList      *last = NULL;
#endif
    int                 MatchFound ;
    IdxRecord           idxRec ;
    DB_LEVEL            qLevel = PATIENT_LEVEL; // highest legal level for a query in the current model
    DB_LEVEL            lLevel = IMAGE_LEVEL;   // lowest legal level for a query in the current model

    OFCondition         cond = EC_Normal;
    OFBool qrLevelFound = OFFalse;

    /**** Is SOPClassUID supported ?
    ***/

    // We only support study root currently

//    if (strcmp( SOPClassUID, UID_FINDPatientRootQueryRetrieveInformationModel) == 0)
//        handle_->rootLevel = PATIENT_ROOT ;

    if (strcmp( SOPClassUID, UID_FINDStudyRootQueryRetrieveInformationModel) == 0)
        handle_->rootLevel = STUDY_ROOT ;
#ifndef NO_PATIENTSTUDYONLY_SUPPORT
//    else if (strcmp( SOPClassUID, UID_RETIRED_FINDPatientStudyOnlyQueryRetrieveInformationModel) == 0)
//        handle_->rootLevel = PATIENT_STUDY ;
#endif
    else
	{
        status->setStatus(STATUS_FIND_Refused_SOPClassNotSupported);
        return (DcmQROsiriXDatabaseError) ;
    }
	
    /**** Parse Identifiers in the Dicom Object
    **** Find Query Level and construct a list
    **** of query identifiers
    ***/
	
//	findRequestIdentifiers->print(COUT);
#if 0 // TBC
    if (findRequestIdentifiers->findAndGetOFStringArray(DCM_SpecificCharacterSet, handle_->findRequestCharacterSet).bad())
        handle_->findRequestCharacterSet.clear();

    if (handle_->findRequestConverter && handle_->findRequestConverter.getSourceCharacterSet() != handle_->findRequestCharacterSet)
        handle_->findRequestConverter.clear();

    handle_->findRequestList = NULL ;
#endif
	
    int elemCount = OFstatic_cast(int, findRequestIdentifiers->card());
    for (int elemIndex=0; elemIndex<elemCount; elemIndex++)
	{
        DcmElement* dcelem = findRequestIdentifiers->getElement(elemIndex);

        elem.XTag = dcelem->getTag().getXTag();
        if (elem.XTag == DCM_QueryRetrieveLevel || DB_TagSupported(elem.XTag))
		{
            elem.ValueLength = dcelem->getLength();
            if (elem.ValueLength == 0)
			{
                elem.PValueField = NULL ;
            }
            else if ((elem.PValueField = OFstatic_cast(char*, malloc(OFstatic_cast(size_t, elem.ValueLength+1)))) == NULL)
			{
                status->setStatus(STATUS_FIND_Refused_OutOfResources);
                return (DcmQROsiriXDatabaseError) ;
            }
            else {
                /* only char string type tags are supported at the moment */
                char *s = NULL;
                dcelem->getString(s);
                /* the available space is always elem.ValueLength+1 */
                OFStandard::strlcpy(elem.PValueField, s, elem.ValueLength+1);
            }
            /** If element is the Query Level, store it in handle
             */

            if (elem.XTag == DCM_QueryRetrieveLevel && elem.PValueField) {
                char *pc ;
                char level [50] ;

                strncpy(level, (char*)elem.PValueField,
                        (elem.ValueLength<50)? (size_t)(elem.ValueLength) : 49) ;

                /*** Skip this two lines if you want strict comparison
                **/

                for (pc = level ; *pc ; pc++)
                    *pc = ((*pc >= 'a') && (*pc <= 'z')) ? 'A' - 'a' + *pc : *pc ;

                if (strncmp (level, PATIENT_LEVEL_STRING,
                             strlen (PATIENT_LEVEL_STRING)) == 0)
                    handle_->queryLevel = PATIENT_LEVEL ;
                else if (strncmp (level, STUDY_LEVEL_STRING,
                                  strlen (STUDY_LEVEL_STRING)) == 0)
                    handle_->queryLevel = STUDY_LEVEL ;
                else if (strncmp (level, SERIE_LEVEL_STRING,
                                  strlen (SERIE_LEVEL_STRING)) == 0)
                    handle_->queryLevel = SERIE_LEVEL ;
                else if (strncmp (level, IMAGE_LEVEL_STRING,
                                  strlen (IMAGE_LEVEL_STRING)) == 0)
                    handle_->queryLevel = IMAGE_LEVEL ;
                else {
                    if (elem. PValueField)
                        free (elem. PValueField) ;

                    DCMQRDB_DEBUG("DB_startFindRequest () : Illegal query level (" << level << ")");
                    status->setStatus(STATUS_FIND_Failed_UnableToProcess);
                    return (DcmQROsiriXDatabaseError);
                }
                qrLevelFound = OFTrue;
            }
#ifdef HANDLE_QUERY_IDENTIFIER
			else {
                /** Else it is a query identifier.
                ** Append it to our RequestList if it is supported
                */
                if (DB_TagSupported (elem. XTag)) {

                    plist = new DB_ElementList ;
                    if (plist == NULL) {
                        status->setStatus(STATUS_FIND_Refused_OutOfResources);
                        return (DcmQROsiriXDatabaseError) ;
                    }
                    DB_DuplicateElement (&elem, &(plist->elem)) ;
                    if (handle_->findRequestList == NULL) {
                        handle_->findRequestList = last = plist ;
                    } else {
                        last->next = plist ;
                        last = plist ;
                    }
                }
            }
#endif
            if ( elem. PValueField ) {
                free (elem. PValueField) ;
            }
        }
    }

    if (!qrLevelFound) {
        /* The Query/Retrieve Level is missing */
        status->setStatus(STATUS_FIND_Failed_IdentifierDoesNotMatchSOPClass);
        DCMQRDB_WARN("DB_startFindRequest(): missing Query/Retrieve Level");
        handle_->idxCounter = -1 ;
        DB_FreeElementList (handle_->findRequestList) ;
        handle_->findRequestList = NULL ;
        return (DcmQROsiriXDatabaseError) ;
    }
	
    switch (handle_->rootLevel)
    {
      case PATIENT_ROOT :
        qLevel = PATIENT_LEVEL ;
        lLevel = IMAGE_LEVEL ;
        break ;
      case STUDY_ROOT :
        qLevel = STUDY_LEVEL ;
        lLevel = IMAGE_LEVEL ;
        break ;
      case PATIENT_STUDY:
        qLevel = PATIENT_LEVEL ;
        lLevel = STUDY_LEVEL ;
        break ;
    }

    /**** Test the consistency of the request list
    ***/

    if (doCheckFindIdentifier) {
        cond = testFindRequestList (handle_->findRequestList, handle_->queryLevel, qLevel, lLevel) ;
        if (cond != EC_Normal) {
            handle_->idxCounter = -1 ;
            DB_FreeElementList (handle_->findRequestList) ;
            handle_->findRequestList = NULL ;
            DCMQRDB_DEBUG("DB_startFindRequest () : STATUS_FIND_Failed_IdentifierDoesNotMatchSOPClass - Invalid RequestList");
            status->setStatus(STATUS_FIND_Failed_IdentifierDoesNotMatchSOPClass);
            return (cond) ;
        }
    }

    /**** Goto the beginning of Index File
    **** Then find the first matching image
    ***/
#if 1
	// Search Core Data here
	if (handle_ -> dataHandler == 0L)
		handle_ -> dataHandler = [OsiriXSCPDataHandler allocRequestDataHandler];
		
	cond = [handle_->dataHandler prepareFindForDataSet:findRequestIdentifiers];
	MatchFound = [handle_->dataHandler findMatchFound];
#endif

    /**** If an error occurred in Matching function
    ****    return a failed status
    ***/

    if (cond != EC_Normal) {
        handle_->idxCounter = -1 ;
        DB_FreeElementList (handle_->findRequestList) ;
        handle_->findRequestList = NULL ;
        DCMQRDB_DEBUG("DB_startFindRequest () : STATUS_FIND_Failed_UnableToProcess");
        status->setStatus(STATUS_FIND_Failed_UnableToProcess);

        return (cond) ;
    }

    /**** If a matching image has been found,
    ****         add index record to UID found list
    ****    prepare Response List in handle
    ****    return status is pending
    ***/

    if (MatchFound) {
//        DB_UIDAddFound (handle_, &idxRec) ;
//        makeResponseList (handle_, &idxRec) ;
        DCMQRDB_DEBUG("DB_startFindRequest () : STATUS_Pending");
        status->setStatus(STATUS_Pending);
        return (EC_Normal) ;
    }

    /**** else no matching image has been found,
    ****    free query identifiers list
    ****    status is success
    ***/

    else {
        handle_->idxCounter = -1 ;
        DB_FreeElementList (handle_->findRequestList) ;
        handle_->findRequestList = NULL ;
        DCMQRDB_DEBUG("DB_startFindRequest () : STATUS_Success");
        status->setStatus(STATUS_Success);

        return (EC_Normal) ;
    }
}

/********************
**      Get next find response in Database
 */

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::nextFindResponse (
                DcmDataset **findResponseIdentifiers,
                DcmQueryRetrieveDatabaseStatus *status,
                const DcmQueryRetrieveCharacterSetOptions& characterSetOptions)
{
    DCMQRDB_INFO("nextFindResponse () : start");

	OFCondition cond = EC_Normal;
	BOOL isComplete;

    *findResponseIdentifiers = new DcmDataset ;
    DCMQRDB_INFO("nextFindResponse () : new dataset");
	
	if (handle_ -> dataHandler == 0L)
		handle_ -> dataHandler = [OsiriXSCPDataHandler allocRequestDataHandler];
		
	cond = [handle_ ->dataHandler nextFindObject:*findResponseIdentifiers isComplete:&isComplete];
    DCMQRDB_INFO("nextFindResponse () : next response");

	if (isComplete) {
        delete *findResponseIdentifiers;
		*findResponseIdentifiers = NULL ;
        status->setStatus(STATUS_Success);
        DCMQRDB_INFO("nextFindResponse () : STATUS_Success");
        return (EC_Normal) ;
	}
    
	if ( *findResponseIdentifiers != NULL ) {
		status->setStatus(STATUS_Pending);
        DCMQRDB_DEBUG("nextFindResponse () : STATUS_Pending");
		return (EC_Normal) ;
	}
	
	return DcmQROsiriXDatabaseError;
}

/********************
**      Cancel find request
 */

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::cancelFindRequest (DcmQueryRetrieveDatabaseStatus *status)
{
	return DcmQROsiriXDatabaseError;
}

#pragma mark - MOVE

/* ========================= MOVE ========================= */

//have preferred Syntax for move

/************
 *      Test a Move Request List
 *      Returns EC_Normal if OK, else returns QR_EC_IndexDatabaseError
 */

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::testMoveRequestList (
                DB_ElementList  *findRequestList,
                DB_LEVEL        queryLevel,
                DB_LEVEL        infLevel,
                DB_LEVEL        lowestLevel
                )
{
    return EC_Normal ;
}

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::startMoveRequest(
        const char      *SOPClassUID,
        DcmDataset      *moveRequestIdentifiers,
        DcmQueryRetrieveDatabaseStatus  *status)
{
    DB_SmallDcmElmt     elem ;
#ifdef HANDLE_QUERY_IDENTIFIER
    DB_ElementList      *plist = NULL;
    DB_ElementList      *last = NULL;
#endif
    IdxRecord           idxRec ;
    DB_LEVEL            qLevel = PATIENT_LEVEL; // highest legal level for a query in the current model
    DB_LEVEL            lLevel = IMAGE_LEVEL;   // lowest legal level for a query in the current model

    OFCondition         cond = EC_Normal;
    OFBool qrLevelFound = OFFalse;

    /**** Is SOPClassUID supported ?
    ***/

    // We only support study root currently

    if (strcmp( SOPClassUID, UID_MOVEStudyRootQueryRetrieveInformationModel) == 0)
        handle_->rootLevel = STUDY_ROOT ;
#ifndef NO_GET_SUPPORT
    /* experimental support for GET */
    else if (strcmp( SOPClassUID, UID_GETStudyRootQueryRetrieveInformationModel) == 0)
        handle_->rootLevel = STUDY_ROOT ;
#endif
    else
    {
        status->setStatus(STATUS_MOVE_Failed_SOPClassNotSupported);
        return (DcmQROsiriXDatabaseError) ;
    }
    
    /**** Parse Identifiers in the Dicom Object
    **** Find Query Level and construct a list
    **** of query identifiers
    ***/

    int elemCount = (int)(moveRequestIdentifiers->card());
    for (int elemIndex=0; elemIndex<elemCount; elemIndex++) {

        DcmElement* dcelem = moveRequestIdentifiers->getElement(elemIndex);

        elem.XTag = dcelem->getTag().getXTag();
        if (elem.XTag == DCM_QueryRetrieveLevel || DB_TagSupported(elem.XTag)) {
            elem.ValueLength = dcelem->getLength();
            if (elem.ValueLength == 0) {
                elem.PValueField = NULL ;
            } else if ((elem.PValueField = (char*)malloc((size_t)(elem.ValueLength+1))) == NULL) {
                status->setStatus(STATUS_MOVE_Failed_UnableToProcess);
                return (DcmQROsiriXDatabaseError) ;
            } else {
                /* only char string type tags are supported at the moment */
                char *s = NULL;
                dcelem->getString(s);
                /* the available space is always elem.ValueLength+1 */
                OFStandard::strlcpy(elem.PValueField, s, elem.ValueLength+1);
            }
            /** If element is the Query Level, store it in handle
             */

            if (elem. XTag == DCM_QueryRetrieveLevel && elem.PValueField) {
                char *pc ;
                char level [50] ;

                strncpy (level, (char *) elem. PValueField, (size_t)((elem. ValueLength < 50) ? elem. ValueLength : 49)) ;

                /*** Skip this two lines if you want strict comparison
                **/

                for (pc = level ; *pc ; pc++)
                    *pc = ((*pc >= 'a') && (*pc <= 'z')) ? 'A' - 'a' + *pc : *pc ;

                if (strncmp (level, PATIENT_LEVEL_STRING,
                             strlen (PATIENT_LEVEL_STRING)) == 0)
                    handle_->queryLevel = PATIENT_LEVEL ;
                else if (strncmp (level, STUDY_LEVEL_STRING,
                                  strlen (STUDY_LEVEL_STRING)) == 0)
                    handle_->queryLevel = STUDY_LEVEL ;
                else if (strncmp (level, SERIE_LEVEL_STRING,
                                  strlen (SERIE_LEVEL_STRING)) == 0)
                    handle_->queryLevel = SERIE_LEVEL ;
                else if (strncmp (level, IMAGE_LEVEL_STRING,
                                  strlen (IMAGE_LEVEL_STRING)) == 0)
                    handle_->queryLevel = IMAGE_LEVEL ;
                else {
                    if (elem. PValueField)
                        free (elem. PValueField) ;

                    DCMQRDB_DEBUG("DB_startMoveRequest () : Illegal query level (" << level << ")");
                    status->setStatus(STATUS_MOVE_Failed_UnableToProcess);
                    return (DcmQROsiriXDatabaseError) ;
                }
                qrLevelFound = OFTrue;
                
            }
#ifdef HANDLE_QUERY_IDENTIFIER
            else {
                /** Else it is a query identifier
                ** Append it to our RequestList if it is supported
                ** Not sure we need this either
                */
                if (! DB_TagSupported (elem. XTag))
                    continue ;

                plist = new DB_ElementList ;
                if (plist == NULL) {
                    status->setStatus(STATUS_FIND_Refused_OutOfResources);
                    return (DcmQROsiriXDatabaseError) ;
                }
                DB_DuplicateElement (&elem, & (plist->elem)) ;
                if (handle_->findRequestList == NULL) {
                    handle_->findRequestList = last = plist ;
                } else {
                    last->next = plist ;
                    last = plist ;
                }
            }
#endif
            if ( elem. PValueField ) {
                free (elem. PValueField) ;
            }
        }
    }

    if (!qrLevelFound) {
        /* The Query/Retrieve Level is missing */
        status->setStatus(STATUS_MOVE_Failed_IdentifierDoesNotMatchSOPClass);
        DCMQRDB_WARN("DB_startMoveRequest(): missing Query/Retrieve Level");
        handle_->idxCounter = -1 ;
        DB_FreeElementList (handle_->findRequestList) ;
        handle_->findRequestList = NULL ;
        return (DcmQROsiriXDatabaseError) ;
    }
    
    // Value stored to 'qLevel' is never read
    // Value stored to 'lLevel' is never read
    switch (handle_->rootLevel)
    {
      case PATIENT_ROOT :
        qLevel = PATIENT_LEVEL ;
        lLevel = IMAGE_LEVEL ;
        break ;
      case STUDY_ROOT :
        qLevel = STUDY_LEVEL ;
        lLevel = IMAGE_LEVEL ;
        break ;
      case PATIENT_STUDY:
        qLevel = PATIENT_LEVEL ;
        lLevel = STUDY_LEVEL ;
        break ;
    }
    
        /**** Then find the first matching image
    ***/
    
    // Search Core Data here
    //NSLog(@"search core data for move");
    if (handle_ -> dataHandler == 0L)
        handle_ -> dataHandler = [OsiriXSCPDataHandler allocRequestDataHandler];
    
    handle_ -> dataHandler.callingAET = [NSString stringWithString: handle_ -> callingAET];
    
    cond = [handle_->dataHandler prepareMoveForDataSet:moveRequestIdentifiers];
    handle_->NumberRemainOperations = [handle_->dataHandler moveMatchFound];
    //NSLog(@"NumberRemainOperations: %d", [handle_->dataHandler moveMatchFound]);
    
     /**** If an error occured in Matching function
    ****    return a failed status
    ***/
    

    if ( handle_->NumberRemainOperations > 0 ) {
        DCMQRDB_DEBUG("DB_startMoveRequest : STATUS_Pending");
        status->setStatus(STATUS_Pending);
        return (EC_Normal) ;
    }

    /**** else no matching image has been found,
    ****    free query identifiers list
    ****    status is success
    ***/

    else {
        handle_->idxCounter = -1 ;
        DCMQRDB_DEBUG("DB_startMoveRequest : STATUS_Success");
        status->setStatus(STATUS_Success);
        return (EC_Normal) ;
    }
}

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::nextMoveResponse(
      char *SOPClassUID,
      char *SOPInstanceUID,
      char *imageFileName,
      unsigned short *numberOfRemainingSubOperations,
      DcmQueryRetrieveDatabaseStatus *status)
{
    return this->nextMoveResponse(SOPClassUID, sizeof(SOPClassUID),
                                  SOPInstanceUID, sizeof(SOPInstanceUID),
                                  imageFileName, sizeof(imageFileName),
                                  numberOfRemainingSubOperations,
                                  status);
}

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::nextMoveResponse(
                  char *SOPClassUID,
                  size_t SOPClassUIDSize,
                  char *SOPInstanceUID,
                  size_t SOPInstanceUIDSize,
                  char *imageFileName,
                  size_t imageFileNameSize,
                  unsigned short *numberOfRemainingSubOperations,
                  DcmQueryRetrieveDatabaseStatus *status)
{
    /**** If all matching images have been retrieved,
    ****    status is success
    ***/

    if ( handle_->NumberRemainOperations <= 0 ) {
        status->setStatus(STATUS_Success);
        return (EC_Normal) ;
    }

    *numberOfRemainingSubOperations = --handle_->NumberRemainOperations ;
    status->setStatus(STATUS_Pending);
    
    /**** Goto the next matching image number ***/
    if (handle_ -> dataHandler == 0L)
        handle_ -> dataHandler = [OsiriXSCPDataHandler allocRequestDataHandler];
    
    OFCondition cond = [handle_->dataHandler nextMoveObject:imageFileName];
    DcmFileFormat fileformat;
    cond = fileformat.loadFile(imageFileName);
    
    if (cond.good())
    {
        const char *sopclass = 0L;
        const char *sopinstance = 0L;
        
        cond = fileformat.getDataset()->findAndGetString(DCM_SOPClassUID, sopclass, OFFalse);
        if (cond.good())
        {
            cond = fileformat.getDataset()->findAndGetString(DCM_SOPInstanceUID, sopinstance, OFFalse);
            if (cond.good())
            {
                if (SOPClassUID != 0L &&
                    sopclass != 0L &&
                    SOPInstanceUID != 0L &&
                    sopinstance != 0L)
                {
                    OFStandard::strlcpy(SOPClassUID, (char *) sopclass, SOPClassUIDSize) ;
                    OFStandard::strlcpy(SOPInstanceUID, (char *) sopinstance, SOPInstanceUIDSize) ;
                }
                else
                    cond = EC_IllegalParameter;
            }
        }
    }
    
    return cond;
}

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::cancelMoveRequest (DcmQueryRetrieveDatabaseStatus *status)
{
    DB_CounterList *plist ;

    while (handle_->moveCounterList) {
        plist  = handle_->moveCounterList ;
        handle_->moveCounterList = handle_->moveCounterList->next ;
        free (plist) ;
    }

    status->setStatus(STATUS_MOVE_Cancel_SubOperationsTerminatedDueToCancelIndication);
    
    //DB_unlock();

    return (EC_Normal) ;
}

#pragma mark - STORE

/*************************
**  Add data from imageFileName to database
 */

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::storeRequest(
    const char *SOPClassUID,
    const char *SOPInstanceUID,
    const char *imageFileName,
    DcmQueryRetrieveDatabaseStatus *status,
    OFBool     isNew)
{
 return EC_Normal;
}

#pragma mark -

void DcmQueryRetrieveOsiriXDatabaseHandle::setDebugLevel(int dLevel)
{
    debugLevel = dLevel;
}

int DcmQueryRetrieveOsiriXDatabaseHandle::getDebugLevel() const
{
    return debugLevel;
}

#pragma mark - UTILS

/* ========================= UTILS ========================= */


const char *DcmQueryRetrieveOsiriXDatabaseHandle::getStorageArea() const
{
  return handle_->storageArea;
}
/*
const char *DcmQueryRetrieveOsiriXDatabaseHandle::getIndexFilename() const
{
  return handle_->indexFilename;
}
*/

void DcmQueryRetrieveOsiriXDatabaseHandle::setIdentifierChecking(OFBool checkFind, OFBool checkMove)
{
    doCheckFindIdentifier = checkFind;
    doCheckMoveIdentifier = checkMove;
}

/***********************
 *      Creates a handle
 */

DcmQueryRetrieveOsiriXDatabaseHandle::DcmQueryRetrieveOsiriXDatabaseHandle(
    const char *callingAET,
    OFCondition& result)
:handle_(NULL)
, quotaSystemEnabled(OFFalse)
, doCheckFindIdentifier(OFFalse)
, doCheckMoveIdentifier(OFFalse)
, fnamecreator()
, debugLevel(0)
{

    //handle_ = (DB_OsiriX_Handle *) calloc ( sizeof(DB_OsiriX_Handle),1);
    handle_ = new DB_OsiriX_Handle;
    
    DCMQRDB_DEBUG("DB_createHandle () : Handle created for " << handle_->storageArea);
    /*
    DCMQRDB_DEBUG("                     maxStudiesPerStorageArea: " << handle_->maxStudiesPerStorageArea
            << " maxBytesPerStudy: " << maxBytesPerStudy);
     */

    if (handle_)
    {
        bzero( handle_, sizeof(DB_OsiriX_Handle));
        handle_ -> callingAET = [NSString stringWithUTF8String: callingAET];
        handle_ -> findRequestList = NULL;
        handle_ -> findResponseList = NULL;
        handle_ -> uidList = NULL;
        result = EC_Normal;
        handle_ -> dataHandler = NULL;
        handle_ -> imageCount = 0;
        handle_ -> logCreated = NO;
    }
    else
        result = DcmQROsiriXDatabaseError;

    return;
}

/***********************
 *      Destroys a handle
 */

DcmQueryRetrieveOsiriXDatabaseHandle::~DcmQueryRetrieveOsiriXDatabaseHandle()
{
    if (handle_)
    {
        // set logEntry to complete
       if ( handle_->logDictionary)
       {
           [handle_->logDictionary setObject: @"Complete" forKey: @"logMessage"];
           [handle_->logDictionary setObject: [NSDate date] forKey: @"logEndTime"];
           
           [[LogManager currentLogManager] addLogLine: handle_->logDictionary];
           
           [handle_->logDictionary release];
           handle_->logDictionary = nil;
        }

        /* Free lists */
        DB_FreeElementList (handle_ -> findRequestList);
        DB_FreeElementList (handle_ -> findResponseList);
        DB_FreeUidList (handle_ -> uidList);
        
        [handle_ -> dataHandler release];
        
        free ( (char *) handle_);
        handle_ = nil;
    }
}

/**********************************
 *      Provides a storage filename
 */

OFCondition DcmQueryRetrieveOsiriXDatabaseHandle::makeNewStoreFileName(
                const char      *SOPClassUID,
                const char      * /* SOPInstanceUID */ ,
                char            *newImageFileName,
                size_t          newImageFileNameLen)
{
    OFString filename;
    char prefix[80];

    const char *m = dcmSOPClassUIDToModality(SOPClassUID);
    if (m==NULL) m = "XX";
    sprintf(prefix, "%s_%d_", m, getpid());    // getpid is very important, to be sure that this filename is UNIQUE, if multiple associations are currently running

    // unsigned int seed = fnamecreator.hashString(SOPInstanceUID);
    unsigned int seed = (unsigned int)time(NULL);
    newImageFileName[0]=0; // return empty string in case of error

    if (! fnamecreator.makeFilename(seed, [[BrowserController currentBrowser] cfixedTempNoIndexDirectory], prefix, ".dcm", filename))
    {
        return DcmQROsiriXDatabaseError;
    }


    OFStandard::strlcpy(newImageFileName, filename.c_str(), newImageFileNameLen);
    return EC_Normal;
}

/**************************************
	Handle Factory
***************************************/

DcmQueryRetrieveOsiriXDatabaseHandleFactory::DcmQueryRetrieveOsiriXDatabaseHandleFactory()
: DcmQueryRetrieveDatabaseHandleFactory()

{
}

DcmQueryRetrieveOsiriXDatabaseHandleFactory::~DcmQueryRetrieveOsiriXDatabaseHandleFactory()
{
}

DcmQueryRetrieveDatabaseHandle *DcmQueryRetrieveOsiriXDatabaseHandleFactory::createDBHandle(
    const char * callingAETitle,
    const char *calledAETitle,
    OFCondition& result) const
{
  return new DcmQueryRetrieveOsiriXDatabaseHandle( callingAETitle, result);
}





