//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//  Created by Alex Bettarini on 16 Jan 2019
//
/*  At first removed, then modified
    the second part of this file which is C++ code that is in the DCMTK sources
 */

#include "dcmtk/config/osconfig.h"    /* make sure OS specific configuration is included first */

#import "BrowserController.h"
#import "ThreadsManager.h"
#import "DicomDatabase.h"
#import "NSThread+N2.h"
#import "AppController.h"
#import "N2Debug.h"
#import "ContextCleaner.h"

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

#include <signal.h>

//#import "dcmtk/dcmnet/dimse.h"
#include "DcmQueryRetrieveOsiriSCP.h"

#import "tmp_locations.h"

extern int AbortAssociationTimeOut;

static int numberOfActiveAssociations = 0;

////////////////////////////////////////////////////////////////////////////////

//static N2ConnectionListener* listenerForSCPProcess = nil;
//
//@interface listenerForSCPProcessClass : N2Connection{
//    
//    NSPoint origin;
//}
//
//@end
//
//@implementation listenerForSCPProcessClass
//
//-(id)initWithAddress:(NSString *)address port:(NSInteger)port is:(NSInputStream *)is os:(NSOutputStream *)os
//{
//    if( (self = [super initWithAddress:address port:port is:is os:os]))
//    {
//        NSLog( @"SCP Process Connected");
//    }
//    
//    return self;
//}
//
//
//-(void)handleData:(NSMutableData*)data
//{
//    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//    @try
//    {
//        NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData: data];
//        
//        NSLog( @"***** %@", dict);
//        
//        NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys: @"Hello World", @"message", nil];
//        
//        [self writeData: [NSKeyedArchiver archivedDataWithRootObject: response]];
//    }
//    @catch (NSException* e)
//    {
//        N2LogException( e);
//    }
//    @finally
//    {
//        [pool release];
//    }
//}
//@end

////////////////////////////////////////////////////////////////////////////////

@implementation ContextCleaner

+ (void) waitUnlockFileWithPID: (NSDictionary*) dict
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Father
    [NSThread sleepForTimeInterval: 0.3]; // To allow the creation of lock_process file with corresponding pid
    
    NSPersistentStoreCoordinator *dbLock = [dict valueForKey: @"dbStoreCoordinator"];
    
    [dbLock lock];
    
    // Father
    [NSThread sleepForTimeInterval: 0.3]; // To allow the creation of lock_process file with corresponding pid
    
	BOOL fileExist = YES;
	int pid = [[dict valueForKey: @"pid"] intValue], inc = 0, rc = pid, state;
	char dir[ 1024];
	sprintf( dir, "%slock_process-%d", [NSTemporaryDirectory() UTF8String], pid);

    #define TIMEOUT 1200 // 1200*100000 = 120 secs
    #define DBTIMEOUT 400 // = 40 secs
    
	do
	{
		FILE * pFile = fopen (dir,"r");
		if( pFile)
		{
			rc = waitpid( pid, &state, WNOHANG);	// Check to see if this pid is still alive?
			fclose (pFile);
		}
		else
			fileExist = NO;
            
            usleep( 100000);
            inc++;
        
        if( inc >= DBTIMEOUT)
        {
            [dbLock unlock];
            dbLock = nil;
        }
	}
    while( fileExist == YES && inc < TIMEOUT && rc >= 0);
	
	if( inc >= TIMEOUT)
	{
		kill( pid, 15);
		NSLog( @"******* waitUnlockFile for %d sec", inc/10);
	}
	
	if( rc < 0)
	{
        NSLog( @"******* waitUnlockFile : child process died... %d / %d", rc, errno);
		kill( pid, 15);
	}
	
	unlink( dir);
    
    [dbLock unlock];
    dbLock = nil;
	
    [dbLock unlock];
    dbLock = nil;
    
    NSString *pathKillAll  = [NSTemporaryDirectory() stringByAppendingPathComponent:@"kill_all_storescu"];
    NSString *pathErrorMsg = [NSTemporaryDirectory() stringByAppendingPathComponent:@"error_message"];
	if( [[NSFileManager defaultManager] fileExistsAtPath: pathKillAll] == NO)
	{
		NSString *str = [NSString stringWithContentsOfFile: pathErrorMsg];
		[[NSFileManager defaultManager] removeItemAtPath: pathErrorMsg error: nil];
		
		if( str && [str length] > 0)
			[[AppController sharedAppController] performSelectorOnMainThread: @selector(displayListenerError:) withObject: str waitUntilDone: NO];
	}
    
    // And finally release memory on the father side, after the death of the process
    inc = 0;
    do
	{
		rc = waitpid( pid, &state, WNOHANG);	// Check to see if this pid is still alive?
		
        usleep( 100000);
        inc++;
	}
    #define TIMEOUTRELEASE 60000 // 60000*100000 = 6000 secs = 100 min
	while( inc < TIMEOUTRELEASE && rc >= 0);
    
    [NSThread sleepForTimeInterval: 5];
    
    T_ASC_Association *assoc = (T_ASC_Association*) [[dict valueForKey: @"assoc"] pointerValue];
    OFCondition cond = EC_Normal;
    
    /* the child will handle the association, we can drop it */
    cond = ASC_dropAssociation(assoc);
    if (cond.bad())
    {
        //DcmQueryRetrieveOptions::errmsg("Cannot Drop Association:");
        DimseCondition::dump(cond);
    }
    
    cond = ASC_destroyAssociation(&assoc);
    if (cond.bad())
    {
        //DcmQueryRetrieveOptions::errmsg("Cannot Destroy Association:");
        DimseCondition::dump(cond);
    }
    
	[pool release];
}

+ (void) waitForHandledAssociations
{
    while( numberOfActiveAssociations > 0)
        [NSThread sleepForTimeInterval: 0.1];
}

+ (void) handleAssociation: (NSDictionary*) d
{
    numberOfActiveAssociations++;
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    @try
    {
        T_ASC_Association * assoc = (T_ASC_Association*) [[d valueForKey: @"assoc"] pointerValue];
        DcmQueryRetrieveOsiriSCP *scp = (DcmQueryRetrieveOsiriSCP*) [[d valueForKey: @"DcmQueryRetrieveSCP"] pointerValue];
        
        if( assoc && scp)
        {
            OFCondition cond = scp->handleAssociation(assoc, YES);
            
            cond = ASC_dropAssociation(assoc);
            if (cond.bad())
                DimseCondition::dump(cond);
            
            cond = ASC_destroyAssociation(&assoc);
            if (cond.bad())
                DimseCondition::dump(cond);
        }
    }
    @catch (NSException *e) {
        N2LogException( e);
    }
    
    [[DicomDatabase activeLocalDatabase] initiateImportFilesFromIncomingDirUnlessAlreadyImporting];
    
    [pool release];
    
    numberOfActiveAssociations--;
}
@end

#pragma mark -

extern "C"
{
	void (*signal(int signum, void (*sighandler)(int)))(int);
	
	void silent_exit_on_sig(int sig_num)
	{
		printf ("\rSignal %d received in OsiriX child process - will quit silently.\r", sig_num);
		_Exit(3);
	}
}

NSManagedObjectContext *staticContext = nil;
