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

#import <Cocoa/Cocoa.h>
#import "DDKeychain.h"

#import "tmp_locations.h"

typedef enum
{
	RequirePeerCertificate = 0,
	VerifyPeerCertificate,
	IgnorePeerCertificate
} TLSCertificateVerificationType;

// NSString *
#define TLS_SEED_FILE                [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"OsiriXTLSSeed"]
#define TLS_PRIVATE_KEY_FILE         [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"TLSKey"]
#define TLS_CERTIFICATE_FILE         [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"TLSCert"]
#define TLS_TRUSTED_CERTIFICATES_DIR [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"TLSTrustedCert"]
#define TLS_KEYCHAIN_IDENTITY_NAME_CLIENT   @"com.osirixviewer.dicomtlsclient"
#define TLS_KEYCHAIN_IDENTITY_NAME_SERVER   @"com.osirixviewer.dicomtlsserver"

// char *
#define TLS_WRITE_SEED_FILE          [[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"OsiriXTLSSeedWrite"] UTF8String]

/** \brief
 A utility class for secure DICOM connections with TLS.
 It provides an access to Mac OS X Keychain.
 */
@interface DICOMTLS : NSObject {

}

#pragma mark - Cipher Suites
/**
	Returns the list of available Ciphersuites.
	These are basically the one available through DCMTK.
 */
+ (NSArray*)availableCipherSuites;
+ (NSArray*)defaultCipherSuites;

+ (NSString*) TLS_PRIVATE_KEY_PASSWORD;
+ (void) eraseKeys;

#pragma mark - Keychain Access

+ (void)generateCertificateAndKeyForLabel:(NSString*)label;
+ (void)generateCertificateAndKeyForLabel:(NSString*)label withStringID:(NSString*)stringID;

+ (void)generateCertificateAndKeyForServerAddress:(NSString*)address port:(int)port AETitle:(NSString*)aetitle;
+ (void)generateCertificateAndKeyForServerAddress:(NSString*)address port:(int)port AETitle:(NSString*)aetitle withStringID:(NSString*)stringID;

+ (NSString*)uniqueLabelForServerAddress:(NSString*)address port:(NSString*)port AETitle:(NSString*)aetitle;

+ (NSString*)keyPathForLabel:(NSString*)label;
+ (NSString*)keyPathForLabel:(NSString*)label withStringID:(NSString*)stringID;

+ (NSString*)keyPathForServerAddress:(NSString*)address port:(int)port AETitle:(NSString*)aetitle;
+ (NSString*)keyPathForServerAddress:(NSString*)address port:(int)port AETitle:(NSString*)aetitle withStringID:(NSString*)stringID;

+ (NSString*)certificatePathForLabel:(NSString*)label;
+ (NSString*)certificatePathForLabel:(NSString*)label withStringID:(NSString*)stringID;

+ (NSString*)certificatePathForServerAddress:(NSString*)address port:(int)port AETitle:(NSString*)aetitle;
+ (NSString*)certificatePathForServerAddress:(NSString*)address port:(int)port AETitle:(NSString*)aetitle withStringID:(NSString*)stringID;
	
@end
