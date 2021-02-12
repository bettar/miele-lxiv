//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//  Created by Alex Bettarini on 12 May 2015
//

#include "dcmtk/config/osconfig.h"    /* make sure OS specific configuration is included first */

#import "BrowserController.h"
#import "AppController.h"
#import "DicomDatabase.h"

#include "dcmtk/dcmqrdb/dcmqrsrv.h"
#include "dcmtk/dcmqrdb/dcmqropt.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmqrdb/dcmqrdba.h"
#include "dcmtk/dcmqrdb/dcmqrcbf.h"    /* for class DcmQueryRetrieveFindContext */
#include "dcmtk/dcmqrdb/dcmqrcbm.h"    /* for class DcmQueryRetrieveMoveContext */
#include "dcmtk/dcmqrdb/dcmqrcbg.h"    /* for class DcmQueryRetrieveGetContext */
#include "dcmtk/dcmqrdb/dcmqrcbs.h"    /* for class DcmQueryRetrieveStoreContext */
#include "dcmtk/dcmdata/dcmetinf.h"
#include "dcmtk/dcmnet/dul.h"

#ifdef WITH_SQL_DATABASE
#include "dcmtk/dcmqrdbx/dcmqrdbq.h"
#else
//#include "dcmtk/dcmqrdb/dcmqrdbi.h"
#include "dcmqrdbq.h" // glue/dcmqrdb
#endif

#include "dcmtk/dcmdata/dcdeftag.h"
#include "dcmtk/dcmnet/dimse.h"

#include "DcmQueryRetrieveOsiriSCP.h"
#include "DcmQueryRetrieveGetOurContext.h"

#import "NSThread+N2.h"

#import "tmp_locations.h"

BOOL forkedProcess = NO;

static char *last(char *p, int c)
{
    char *t;    
    if ((t = strrchr(p, c)) != NULL)
        return t + 1;
    
    return p;
}

static void getCallback(
                        /* in */
                        void *callbackData,
                        OFBool cancelled, T_DIMSE_C_GetRQ *request,
                        DcmDataset *requestIdentifiers, int responseCount,
                        /* out */
                        T_DIMSE_C_GetRSP *response, DcmDataset **stDetail,
                        DcmDataset **responseIdentifiers)
{
#if 1
    DcmQueryRetrieveGetOurContext *context = OFstatic_cast(DcmQueryRetrieveGetOurContext *, callbackData);
#else
    DcmQueryRetrieveGetContext *context = OFstatic_cast(DcmQueryRetrieveGetContext *, callbackData);
#endif
    context->callbackHandler(cancelled, request, requestIdentifiers, responseCount, response, stDetail, responseIdentifiers);
    
    if( forkedProcess == NO)
        [[NSThread currentThread] setProgress:1.0/
                                                 (response->NumberOfCompletedSubOperations+
                                                  response->NumberOfFailedSubOperations+
                                                  response->NumberOfWarningSubOperations+
                                                  response->NumberOfRemainingSubOperations)
                                                 *
                                                 (response->NumberOfCompletedSubOperations+
                                                  response->NumberOfFailedSubOperations+
                                                  response->NumberOfWarningSubOperations)];
}

// See DIMSE_StoreProviderCallback in dimse.h
static void storeCallback(
  /* in */
  void *callbackData,
  T_DIMSE_StoreProgress *progress,  /* progress state */
  T_DIMSE_C_StoreRQ *req,           /* original store request */
  char *imageFileName,              /* being received into */
  DcmDataset **imageDataSet,        /* being received into */
  /* out */
  T_DIMSE_C_StoreRSP *rsp,          /* final store response */
  DcmDataset **statusDetail)
{
  DcmQueryRetrieveStoreContext *context = OFstatic_cast(DcmQueryRetrieveStoreContext *, callbackData);
  context->callbackHandler(progress, req, imageFileName, imageDataSet, rsp, statusDetail);
}

#pragma mark - class DcmQueryRetrieveOsiriSCP

// Line 362
DcmQueryRetrieveOsiriSCP::DcmQueryRetrieveOsiriSCP(
                                                   const DcmQueryRetrieveConfig& config,
                                                   const DcmQueryRetrieveOptions& options,
                                                   const DcmQueryRetrieveDatabaseHandleFactory& factory,
                                                   const DcmAssociationConfiguration& associationConfiguration)
: DcmQueryRetrieveSCP(config, options, factory, associationConfiguration)
{
    index=0;
//    DCM_dcmdataLogger.setLogLevel(OFLogger::WARN_LOG_LEVEL);
//    DCM_dcmqrdbLogger.setLogLevel(OFLogger::WARN_LOG_LEVEL);
}

void DcmQueryRetrieveOsiriSCP::writeErrorMessage( const char *str)
{
    if( options_.singleProcess_)
    {
        if (str)
            [[AppController sharedAppController] performSelectorOnMainThread: @selector(displayListenerError:)
                                                                  withObject: @(str)
                                                               waitUntilDone: NO];
    }
    else
    {
        char dir[ 1024];
        sprintf( dir, "%serror_message", [NSTemporaryDirectory() UTF8String]);
        unlink( dir);
        
        FILE * pFile = fopen (dir,"w+");
        if( pFile)
        {
            fprintf( pFile, "%s", str);
            fclose (pFile);
        }
    }
}

OFCondition DcmQueryRetrieveOsiriSCP::handleAssociation(T_ASC_Association * assoc, OFBool correctUIDPadding)
{
    index = 0;
    return DcmQueryRetrieveSCP::handleAssociation(assoc, correctUIDPadding);
}

// See DCMTK sources: dcmqrsrv.cc:280
/* Unused, but inserted to help the diff tool
OFCondition DcmQueryRetrieveSCP::findSCP(T_ASC_Association * assoc, T_DIMSE_C_FindRQ * request,
        T_ASC_PresentationContextID presID,
        DcmQueryRetrieveDatabaseHandle& dbHandle)
{
}
*/

OFCondition DcmQueryRetrieveOsiriSCP::getSCP(T_ASC_Association * assoc, T_DIMSE_C_GetRQ * request,
                                             T_ASC_PresentationContextID presID,
                                             DcmQueryRetrieveDatabaseHandle& dbHandle)
{
    OFCondition cond = EC_Normal;

#if 1
    DcmQueryRetrieveGetOurContext context(dbHandle, options_, STATUS_Pending, assoc, request->MessageID, request->Priority, presID);
#else
    DcmQueryRetrieveGetContext context(dbHandle, options_, STATUS_Pending, assoc, request->MessageID, request->Priority, presID);
#endif
    
    DIC_AE aeTitle;
    aeTitle[0] = '\0';
    ASC_getAPTitles(assoc->params, NULL, 0, aeTitle, sizeof(aeTitle), NULL, 0);
    context.setOurAETitle(aeTitle);
    
    OFString temp_str;
    DCMQRDB_INFO("Received Get SCP:" << OFendl << DIMSE_dumpMessage(temp_str, *request, DIMSE_INCOMING));
    
    cond = DIMSE_getProvider(assoc, presID, request,
                             getCallback, &context, options_.blockMode_, options_.dimse_timeout_);
    if (cond.bad()) {
        DCMQRDB_ERROR("Get SCP Failed: " << DimseCondition::dump(temp_str, cond));
    }
    return cond;
}

// See DCMTK sources: dcmqrsrv.cc:330
/* Unused, but inserted to help the diff tool.
OFCondition DcmQueryRetrieveSCP::moveSCP(T_ASC_Association * assoc, T_DIMSE_C_MoveRQ * request,
        T_ASC_PresentationContextID presID, DcmQueryRetrieveDatabaseHandle& dbHandle)
{
}
*/

// see DCMTK source: dcmqrsrv.cc:353
OFCondition DcmQueryRetrieveOsiriSCP::storeSCP(T_ASC_Association * assoc, T_DIMSE_C_StoreRQ * request,
             T_ASC_PresentationContextID presId,
             DcmQueryRetrieveDatabaseHandle& dbHandle,
             OFBool correctUIDPadding)
{
    NSLog(@"DcmQueryRetrieveOsiriSCP.mm %s %d", __FUNCTION__, __LINE__);
#if 0
    // TODO: call base class instead of repeating this block of code (need to resolve imageFileName)
    DcmQueryRetrieveSCP::storeSCP(assoc,request,presId,dbHandle,correctUIDPadding);
#else
    OFCondition cond = EC_Normal;
    OFCondition dbcond = EC_Normal;
    char imageFileName[MAXPATHLEN+1];
    DcmFileFormat dcmff;

#ifndef NDEBUG
    OFLog::configure(OFLogger::DEBUG_LOG_LEVEL);
    //DCM_dcmdataLogger.setLogLevel(OFLogger::DEBUG_LOG_LEVEL);
    //DCM_dcmqrdbLogger.setLogLevel(OFLogger::DEBUG_LOG_LEVEL);
#else
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"verbose_dcmtkStoreScu"])
    {
        OFLog::configure(OFLogger::INFO_LOG_LEVEL);
    }
    else
    {
        OFLog::configure(OFLogger::ERROR_LOG_LEVEL);        
    }
#endif
    
    DcmQueryRetrieveStoreContext context(dbHandle, options_, STATUS_Success, &dcmff, correctUIDPadding);
    
    OFString temp_str;
    DCMQRDB_INFO("Received Store SCP:" << OFendl << DIMSE_dumpMessage(temp_str, *request, DIMSE_INCOMING));
    
    if (!dcmIsaStorageSOPClassUID(request->AffectedSOPClassUID)) {
        /* callback will send back sop class not supported status */
        context.setStatus(STATUS_STORE_Refused_SOPClassNotSupported);
        /* must still receive data */
        //strcpy(imageFileName, NULL_DEVICE_NAME);
        OFStandard::strlcpy(imageFileName, NULL_DEVICE_NAME, sizeof(imageFileName));
    }
    else if (options_.ignoreStoreData_)
    {
        strcpy(imageFileName, NULL_DEVICE_NAME);
        OFStandard::strlcpy(imageFileName, NULL_DEVICE_NAME, sizeof(imageFileName));
    }
    else
    {
        dbcond = dbHandle.makeNewStoreFileName(
            request->AffectedSOPClassUID,
            request->AffectedSOPInstanceUID,
            imageFileName, sizeof(imageFileName));
        
        if (dbcond.bad())
        {
            DCMQRDB_ERROR("storeSCP: Database: makeNewStoreFileName Failed");
            /* must still receive data */
#if 0
            strcpy(imageFileName, NULL_DEVICE_NAME);
#else
            OFStandard::strlcpy(imageFileName, NULL_DEVICE_NAME, sizeof(imageFileName));
#endif

            /* callback will send back out of resources status */
            context.setStatus(STATUS_STORE_Refused_OutOfResources);
        }
    }

#if 1
    FILE *pFile = fopen([[NSTemporaryDirectory() stringByAppendingPathComponent:@"kill_all_storescu"] UTF8String], "r");
    if (pFile)
    {
        fclose (pFile);
        cond = ASC_abortAssociation(assoc);
    }
#endif

#ifdef LOCK_IMAGE_FILES
    /* exclusively lock image file */
#ifdef O_BINARY
    int lockfd = open(imageFileName, (O_WRONLY | O_CREAT | O_TRUNC | O_BINARY), 0666);
#else
    int lockfd = open(imageFileName, (O_WRONLY | O_CREAT | O_TRUNC), 0666);
#endif
    if (lockfd < 0)
    {
        DCMQRDB_ERROR("storeSCP: file locking failed, cannot create file");
        
        /* must still receive data */
        OFStandard::strlcpy(imageFileName, NULL_DEVICE_NAME, sizeof(imageFileName));
        
        /* callback will send back out of resources status */
        context.setStatus(STATUS_STORE_Refused_OutOfResources);
    }
    else
      dcmtk_flock(lockfd, LOCK_EX);
#endif

    context.setFileName(imageFileName);

    // store SourceApplicationEntityTitle in metaheader
    if (assoc && assoc->params)
    {
      const char *aet = assoc->params->DULparams.callingAPTitle;
      if (aet) dcmff.getMetaInfo()->putAndInsertString(DCM_SourceApplicationEntityTitle, aet);
    }

    DcmDataset *dset = dcmff.getDataset();

    /* we must still retrieve the data set even if some error has occurred */

    if (options_.bitPreserving_)
    { /* the bypass option can be set on the command line */
        cond = DIMSE_storeProvider(assoc, presId, request,
                                   imageFileName,
                                   (int)options_.useMetaheader_,
                                   NULL,
                                   storeCallback,
                                   (void*)&context,
                                   options_.blockMode_,
                                   options_.dimse_timeout_);
    }
    else
    {
        cond = DIMSE_storeProvider(assoc, presId, request,
                                   (char *)NULL,
                                   (int)options_.useMetaheader_,
                                   &dset,
                                   storeCallback,
                                   (void*)&context,
                                   options_.blockMode_,
                                   options_.dimse_timeout_);
    }
    
#if 1
    static_cast<DcmQueryRetrieveOsiriXDatabaseHandle *>(&dbHandle) -> updateLogEntry(dset);
#endif

    if (cond.bad())
    {
        DCMQRDB_ERROR("Store SCP Failed: " << DimseCondition::dump(temp_str, cond));
        writeErrorMessage( cond.text());
    }
    
    if (!options_.ignoreStoreData_ &&
        (cond.bad() || (context.getStatus() != STATUS_Success)))
    {
        /* remove file */
        if (strcmp(imageFileName, NULL_DEVICE_NAME) != 0) // don't try to delete /dev/null
        {
            DCMQRDB_INFO("Store SCP - status:" << context.getStatus()
                         << " Deleting Image File:" << imageFileName);
#if 0
            unlink(imageFileName); // The file in TEMP.noindex is deleted
#else
        OFStandard::deleteFile(imageFileName);

#endif
        }
        dbHandle.pruneInvalidRecords();
    }
    
#ifdef LOCK_IMAGE_FILES
    /* unlock image file */
    if (lockfd >= 0)
    {
        dcmtk_flock(lockfd, LOCK_UN);
        close(lockfd);
    }
#endif
#endif
    
#pragma mark - Extra stuff for Miele-LXIV

    // It moves the retrieved file from TEMP to INCOMING
    
    if (strcmp(imageFileName, NULL_DEVICE_NAME) != 0)
    {
        char dir[ 1024];
        sprintf( dir, "%s/%s",
                [[BrowserController currentBrowser] cfixedIncomingNoIndexDirectory],
                last( imageFileName, '/'));
        rename( imageFileName, dir); // Moving the file from TEMP.noindex to INCOMING.noindex
        
        if (forkedProcess == NO && index == 0)
        {
            [[DicomDatabase activeLocalDatabase] initiateImportFilesFromIncomingDirUnlessAlreadyImporting];
        }
        
        index++;
    }
    
    return cond;
}

