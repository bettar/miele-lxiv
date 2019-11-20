//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//  Created by Alex Bettarini on 12 May 2015
//

#include "dcmtk/config/osconfig.h"    /* make sure OS specific configuration is included first */

#import <DCM/DCMObject.h>
#import <DCM/DCM.h>

#import "BrowserController.h"
//#import "AppController.h"
//#import "DicomDatabase.h"
//
//#include "dcmtk/dcmqrdb/dcmqrsrv.h"
//#include "dcmtk/dcmqrdb/dcmqropt.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmqrdb/dcmqrdba.h"
#include "dcmtk/dcmqrdb/dcmqrdbs.h"    /* for class DcmQueryRetrieveDatabaseStatus */
#include "dcmtk/dcmqrdb/dcmqrcnf.h"    /* for DCMQRDB_INFO */
//#include "dcmtk/dcmqrdb/dcmqrcbf.h"    /* for class DcmQueryRetrieveFindContext */
//#include "dcmtk/dcmqrdb/dcmqrcbm.h"    /* for class DcmQueryRetrieveMoveContext */
//#include "dcmtk/dcmqrdb/dcmqrcbg.h"    /* for class DcmQueryRetrieveGetContext */
//#include "dcmtk/dcmqrdb/dcmqrcbs.h"    /* for class DcmQueryRetrieveStoreContext */
//#include "dcmtk/dcmdata/dcmetinf.h"
//#include "dcmtk/dcmnet/dul.h"
//#import "dcmtk/dcmqrdbx/dcmqrdbq.h"
//#include "dcmtk/dcmdata/dcdeftag.h"

#include "DcmQueryRetrieveGetOurContext.h"
#import "dcmtk/dcmnet/dimse.h"       // for getTransferSyntax
#import "dcmtk/dcmnet/diutil.h"

#if 1 //def ON_THE_FLY_COMPRESSION
#include "dcmtk/dcmjpeg/djdecode.h"  /* for dcmjpeg decoders */
#include "dcmtk/dcmjpeg/djencode.h"  /* for dcmjpeg encoders */
#include "dcmtk/dcmdata/dcrledrg.h"  /* for DcmRLEDecoderRegistration */
#include "dcmtk/dcmdata/dcrleerg.h"  /* for DcmRLEEncoderRegistration */
#include "dcmtk/dcmjpeg/djrploss.h"
#include "dcmtk/dcmjpeg/djrplol.h"
#include "dcmtk/dcmdata/dcpixel.h"
#include "dcmtk/dcmdata/dcrlerp.h"
#endif

#include "url.h"

//extern OFCondition decompressFileFormat(DcmFileFormat fileformat, const char *fname);
//extern OFBool compressFileFormat(DcmFileFormat fileformat, const char *fname, char *outfname, E_TransferSyntax newXfer);

extern OFCondition getTransferSyntax(
                  T_ASC_Association *assoc,
                  T_ASC_PresentationContextID pid,
                  E_TransferSyntax *xferSyntax);

static int seed = 0;

#pragma mark - taken from OsiriX dcmqrcbm.mm

OFCondition decompressFileFormat(DcmFileFormat fileformat, const char *fname)
{
    OFBool status = YES;
    OFCondition cond = EC_Normal;
    
    DcmXfer filexfer(fileformat.getDataset()->getOriginalXfer());
#ifndef MIELE_LIGHT
    BOOL useDCMTKForJP2K = [[NSUserDefaults standardUserDefaults] boolForKey: @"useDCMTKForJP2K"];
    
    if (useDCMTKForJP2K == NO &&
       (filexfer.getXfer() == EXS_JPEG2000LosslessOnly ||
        filexfer.getXfer() == EXS_JPEG2000))
    {
        @try
        {
            NSString *path = [NSString stringWithCString:fname encoding:NSUTF8StringEncoding];
            DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile:path decodingPixelData: NO];
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            [dcmObject writeToFile:path
                withTransferSyntax:[DCMTransferSyntax ExplicitVRLittleEndianTransferSyntax]
                           quality:DCMLosslessQuality
                               AET:@"OsiriX"
                        atomically:YES];
            [dcmObject release];
        }
        @catch (NSException *e)
        {
            NSLog( @"*** decompressFileFormat exception: %@", e);
            status = NO;
        }
    }
    else
#endif
    {
        DcmDataset *dataset = fileformat.getDataset();
        
        // decompress data set if compressed
        dataset->chooseRepresentation(EXS_LittleEndianExplicit, NULL);
        
        // check if everything went well
        if (dataset->canWriteXfer(EXS_LittleEndianExplicit))
        {
            fileformat.loadAllDataIntoMemory();
            cond = fileformat.saveFile( fname, EXS_LittleEndianExplicit);
            status = (cond.good()) ? YES : NO;
            
            if( status == NO)
                printf("\n*** decompressFileFormat failed\n");
        }
        else
            status = NO;
    }
    
    printf("\n--- Decompress for C-Move/C-Get\n");
    
    if( status == NO)
        cond = EC_MemoryExhausted;
    
    return cond;
}

// TODO: avoid code duplication, see function compressFile() in DCMTKStoreSCU.mm (ON_THE_FLY_COMPRESSION)
OFBool compressFileFormat(DcmFileFormat fileformat, const char *fname, char *outfname, E_TransferSyntax newXfer)
{
    OFCondition cond = EC_Normal;
    OFBool status = YES;
    DcmDataset *dataset = fileformat.getDataset();
    DcmXfer filexfer(dataset->getOriginalXfer());
    BOOL useDCMTKForJP2K = [[NSUserDefaults standardUserDefaults] boolForKey: @"useDCMTKForJP2K"];

    useDCMTKForJP2K = NO; // FIXME: Testing issue #19, using DCMTK doesn't work.
    
#ifndef MIELE_LIGHT
    if( useDCMTKForJP2K == NO && newXfer == EXS_JPEG2000)
    {
        DCMQRDB_INFO("SEND - Compress JPEG 2000 Lossy");
        @try
        {
            NSString *path = [NSString stringWithCString:fname encoding:NSUTF8StringEncoding];
            NSString *outpath = [NSString stringWithCString:outfname encoding:NSUTF8StringEncoding];
            
            DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile:path decodingPixelData: NO];
            
            unlink( outfname);
            
            [dcmObject writeToFile:outpath
                withTransferSyntax:[DCMTransferSyntax JPEG2000LossyTransferSyntax]
                           quality:DCMHighQuality
                               AET:@OUR_AET
                        atomically:YES];
            [dcmObject release];
        }
        @catch (NSException *e)
        {
            DCMQRDB_ERROR("*** compressFileFormat EXS_JPEG2000 exception: "
                          << [[e description] cStringUsingEncoding:NSUTF8StringEncoding]);
            status = NO;
        }
    }
    else if( useDCMTKForJP2K == NO && newXfer == EXS_JPEG2000LosslessOnly)
    {
        DCMQRDB_INFO("SEND - Compress JPEG 2000 Lossless");
        @try
        {
            NSString *path = [NSString stringWithCString:fname encoding:NSUTF8StringEncoding];
            NSString *outpath = [NSString stringWithCString:outfname encoding:NSUTF8StringEncoding];
            
            DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile:path decodingPixelData: NO];
            
            unlink( outfname);
            
            [dcmObject writeToFile:outpath
                withTransferSyntax:[DCMTransferSyntax JPEG2000LosslessTransferSyntax]
                           quality:DCMLosslessQuality
                               AET:@"OsiriX"
                        atomically:YES];
            [dcmObject release];
        }
        @catch (NSException *e)
        {
            DCMQRDB_ERROR("*** compressFileFormat EXS_JPEG2000LosslessOnly exception: "
                          << [[e description] cStringUsingEncoding:NSUTF8StringEncoding]);
            status = NO;
        }
    }
    else
#endif
    {
        DCMQRDB_INFO("SEND - Compress DCMTK JPEG Lossy");

#ifndef MIELE_LIGHT
//		DcmItem *metaInfo = fileformat.getMetaInfo();
        
        DcmRepresentationParameter *params = nil;
        DJ_RPLossy lossyParams( 90);
        DJ_RPLossy JP2KParams( DCMHighQuality);
        DJ_RPLossy JP2KParamsLossLess( DCMLosslessQuality);
        DcmRLERepresentationParameter rleParams;
        DJ_RPLossless losslessParams(6,0);
        
#if 1
        if (newXfer == EXS_JPEGProcess14SV1)
            printf("\n--- compressFileFormat EXS_JPEGProcess14SV1\n");
        else if (newXfer == EXS_JPEGProcess2_4)
            printf("\n--- compressFileFormat EXS_JPEGProcess2_4\n");
        else if (newXfer == EXS_RLELossless)
            printf("\n--- compressFileFormat EXS_RLELossless\n");
        else if (newXfer == EXS_JPEG2000LosslessOnly)
            printf("\n--- compressFileFormat EXS_JPEG2000LosslessOnly\n");
        else if (newXfer == EXS_JPEG2000)
            printf("\n--- compressFileFormat EXS_JPEG2000\n");
        else if (newXfer == EXS_JPEGLSLossless)
            printf("\n--- compressFileFormat EXS_JPEGLSLossless\n");
        else if (newXfer == EXS_JPEGLSLossy)
            printf("\n--- compressFileFormat EXS_JPEGLSLossy\n");
#endif
        
        if (newXfer == EXS_JPEGProcess14SV1)
            params = &losslessParams;
        else if (newXfer == EXS_JPEGProcess2_4)
            params = &lossyParams;
        else if (newXfer == EXS_RLELossless)
            params = &rleParams;
        else if (newXfer == EXS_JPEG2000LosslessOnly)
            params = &JP2KParamsLossLess;
        else if (newXfer == EXS_JPEG2000)
            params = &JP2KParams;
        else if (newXfer == EXS_JPEGLSLossless)
            params = &JP2KParamsLossLess;
        else if (newXfer == EXS_JPEGLSLossy)
            params = &JP2KParams;
        
        if( params)
        {
            // this causes the lossless JPEG version of the dataset to be created
            dataset->chooseRepresentation(newXfer, params);
            
            // check if everything went well
            if (dataset->canWriteXfer(newXfer))
            {
                // force the meta-header UIDs to be re-generated when storing the file
                // since the UIDs in the data set may have changed
                // delete metaInfo->remove(DCM_MediaStorageSOPClassUID);
                // delete metaInfo->remove(DCM_MediaStorageSOPInstanceUID);
                
                // store in lossless JPEG format

                fileformat.loadAllDataIntoMemory();
                
                unlink( outfname);
                
                cond = fileformat.saveFile(outfname, newXfer);
                status = (cond.good()) ? YES : NO;
            }
            else
            {
                status = NO;
                DCMQRDB_ERROR("*** compressFileFormat failed");
            }
        }
        else
            status = NO;
#endif
    }
    
    return status;
}
#pragma mark - class DcmQueryRetrieveGetOurContext

/** constructor
 *  @param handle reference to database handle
 *  @param options options for the Q/R service
 *  @param priorstatus prior DIMSE status
 *  @param origassoc pointer to DIMSE association
 *  @param origmsgid DIMSE message ID
 *  @param prior DIMSE priority
 *  @param origpresid presentation context ID
 */
DcmQueryRetrieveGetOurContext::DcmQueryRetrieveGetOurContext(DcmQueryRetrieveDatabaseHandle& handle,
                           const DcmQueryRetrieveOptions& options,
                           DIC_US priorstatus,
                           T_ASC_Association *origassoc,
                           DIC_US origmsgid,
                           T_DIMSE_Priority prior,
                           T_ASC_PresentationContextID origpresid)
: DcmQueryRetrieveGetContext(handle, options, priorstatus, origassoc, origmsgid, prior, origpresid)
{
}

// See DCMTK sources: dcmqrcbg.cc
void DcmQueryRetrieveGetOurContext::getNextImage(DcmQueryRetrieveDatabaseStatus * dbStatus)
{
    OFCondition cond = EC_Normal;
    OFCondition dbcond = EC_Normal;
    DIC_UI subImgSOPClass;      /* sub-operation image SOP Class */
    DIC_UI subImgSOPInstance;   /* sub-operation image SOP Instance */
    char subImgFileName[MAXPATHLEN + 1];    /* sub-operation image file */
    
    /* clear out strings */
    bzero(subImgFileName, sizeof(subImgFileName));
    bzero(subImgSOPClass, sizeof(subImgSOPClass));
    bzero(subImgSOPInstance, sizeof(subImgSOPInstance));
    
    /* get DB response */
    dbcond = dbHandle.nextMoveResponse(subImgSOPClass, sizeof(subImgSOPClass),
                                       subImgSOPInstance, sizeof(subImgSOPInstance),
                                       subImgFileName, sizeof(subImgFileName),
                                       &nRemaining,
                                       dbStatus);
    if (dbcond.bad()) {
        DCMQRDB_ERROR("getSCP: Database: nextMoveResponse Failed ("
                      << DU_cmoveStatusString(dbStatus->status()) << "):");
    }
    
#if 1
    // On the fly conversion:
    E_TransferSyntax xferSyntax;
    T_ASC_PresentationContextID presId;
    
    char outfname[ 4096];
    
    strcpy( outfname, "");
    sprintf( outfname, "%s/QR-CGET-%d-%d.dcm", [[BrowserController currentBrowser] cfixedTempNoIndexDirectory], seed++, getpid());
    unlink( outfname);
    
    presId = ASC_findAcceptedPresentationContextID(origAssoc, subImgSOPClass);
    cond = getTransferSyntax(origAssoc, presId, &xferSyntax);
    
    if (cond.good())
    {
        DcmFileFormat fileformat;
        cond = fileformat.loadFile( subImgFileName);
        
        /* figure out which of the accepted presentation contexts should be used */
        E_TransferSyntax originalXFer = fileformat.getDataset()->getOriginalXfer();
        DcmXfer filexfer( originalXFer);
        
        //on the fly conversion:
        
        DcmXfer preferredXfer( xferSyntax);
        OFBool status = YES;
        
        sprintf( outfname, "%s/QR-CGET-%d-%d.dcm", [[BrowserController currentBrowser] cfixedTempNoIndexDirectory], seed++, getpid());
        unlink( outfname);
        
        if (filexfer.isNotEncapsulated() && preferredXfer.isNotEncapsulated())
        {
            // do nothing
        }
        else if (filexfer.isNotEncapsulated() && preferredXfer.isEncapsulated())
        {
            status = compressFileFormat(fileformat, subImgFileName, outfname, xferSyntax);
            
            if( status)
                strcpy( subImgFileName, outfname);
        }
        else if (filexfer.isEncapsulated() && preferredXfer.isEncapsulated())
        {
            // The file is already compressed, we will re-compress the file.....
            if( strcmp( filexfer.getXferID(), preferredXfer.getXferID()) != 0)
            {
                if ((filexfer.getXfer() == EXS_JPEG2000LosslessOnly && preferredXfer.getXfer() == EXS_JPEG2000) ||
                    (filexfer.getXfer() == EXS_JPEG2000             && preferredXfer.getXfer() == EXS_JPEG2000LosslessOnly))
                {
                    // Switching from JPEG2000 <-> JPEG2000Lossless : we only change the transfer syntax....
                    DCMQRDB_INFO("JPEG2000 <-> JPEG2000Lossless switch");
                    status = compressFileFormat(fileformat, subImgFileName, outfname, xferSyntax);
                    
                    if( status)
                        strcpy( subImgFileName, outfname);
                }
                else if ((filexfer.getXfer() == EXS_JPEGLSLossless && preferredXfer.getXfer() == EXS_JPEGLSLossy) ||
                         (filexfer.getXfer() == EXS_JPEGLSLossy    && preferredXfer.getXfer() == EXS_JPEGLSLossless))
                {
                    // Switching from EXS_JPEGLSLossy <-> EXS_JPEGLSLossless : we only change the transfer syntax....
                    DCMQRDB_INFO("EXS_JPEGLSLossy <-> EXS_JPEGLSLossless switch");
                    status = compressFileFormat(fileformat, subImgFileName, outfname, xferSyntax);
                    
                    if( status)
                        strcpy( subImgFileName, outfname);
                }
                else
                {
                    printf("---- Warning! I'm recompressing files that are already compressed, you should optimize your ts parameters to avoid this: presentation for syntax:%s -> %s\n",
                           dcmFindNameOfUID( filexfer.getXferID()),
                           dcmFindNameOfUID( preferredXfer.getXferID()));
                    cond = decompressFileFormat(fileformat, subImgFileName);
                    
                    DcmFileFormat fileformatDecompress;
                    cond = fileformatDecompress.loadFile( subImgFileName);
                    
                    status = compressFileFormat( fileformatDecompress, subImgFileName, outfname, xferSyntax);
                    
                    if( status)
                        strcpy( subImgFileName, outfname);
                }
            }
        }
        else if (filexfer.isEncapsulated() && preferredXfer.isNotEncapsulated())
        {
            cond = decompressFileFormat(fileformat, subImgFileName);
        }
    }
#endif
    
    if (dbStatus->status() == STATUS_Pending) {
        /* perform sub-op */
        cond = performGetSubOp(subImgSOPClass, subImgSOPInstance, subImgFileName);
        
        if (getCancelled) {
            dbStatus->setStatus(STATUS_GET_Cancel_SubOperationsTerminatedDueToCancelIndication);
            DCMQRDB_INFO("Get SCP: Received C-Cancel RQ");
        }
        
        if (cond != EC_Normal) {
            OFString temp_str;
            DCMQRDB_ERROR("getSCP: Get Sub-Op Failed: " << DimseCondition::dump(temp_str, cond));
            /* clear condition stack */
        }
    }
}
