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

#import "O2DicomPredicateEditorCodeStrings.h"
#import "O2DicomPredicateEditorDCMAttributeTag.h"

@interface O2DicomPredicateEditorOrderedMutableDictionary : NSMutableDictionary {
    NSMutableArray* _sortedKeys;
    NSMutableDictionary* _content;
}

@end

#pragma mark -

@implementation O2DicomPredicateEditorOrderedMutableDictionary

- (id)init {
    if ((self = [super init])) {
        _content = [[NSMutableDictionary alloc] init];
        _sortedKeys = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (id)initWithObjects:(NSArray*)objects forKeys:(NSArray*)keys {
    if ((self = [super init])) {
        _content = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys];
        _sortedKeys = [[NSMutableArray alloc] initWithArray:keys];
    }
    
    return self;
}

- (NSUInteger)count {
    return [_content count];
}

- (id)objectForKey:(id)aKey {
    return [_content objectForKey:aKey];
}

- (NSEnumerator*)keyEnumerator {
    return [_sortedKeys objectEnumerator];
}

- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    [_content setObject:anObject forKey:aKey];
    if ([_sortedKeys containsObject:aKey])
        [_sortedKeys removeObject:aKey];
    [_sortedKeys addObject:aKey];
}

- (void)removeObjectForKey:(id)aKey {
    [_content removeObjectForKey:aKey];
    [_sortedKeys removeObject:aKey];
}

- (void)dealloc {
    [_sortedKeys release];
    [_content release];
    [super dealloc];
}

@end

#pragma mark -

@implementation O2DicomPredicateEditorCodeStrings

+ (NSDictionary*)base {
    static NSMutableDictionary* base = nil;
    if (!base) {
        base = [[NSMutableDictionary alloc] init];
        
        for (NSString* tpl in [NSArray arrayWithObjects:
                               @"dicom3tools-libsrc-strval-base",
                               @"osirix-complementary",
                               nil]) {
            NSString* str = [NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:tpl ofType:@"tpl"]
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];
            str = [str stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
            str = [str stringByReplacingOccurrencesOfString:@"  " withString:@" "];
            str = [str stringByReplacingOccurrencesOfString:@", \n" withString:@",\n"];
            str = [str stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
            
            NSScanner* s = [NSScanner scannerWithString:str];
            while (!s.isAtEnd) {
                [s scanUpToString:@"StringValues" intoString:NULL];
                if (s.isAtEnd)
                    break;
                
                [s scanUpToString:@"=" intoString:NULL];
                [s scanUpToString:@"\"" intoString:NULL];
                s.scanLocation = s.scanLocation+1;

                NSString* cs = nil;
                [s scanUpToString:@"\"" intoString:&cs];
                
                [s scanUpToString:@"{" intoString:NULL];
                s.scanLocation += 1;
                
                NSString* vps = nil;
                [s scanUpToString:@"}" intoString:&vps];
                
                NSMutableDictionary* b = [[[O2DicomPredicateEditorOrderedMutableDictionary alloc] init] autorelease];
                
                static NSCharacterSet* wsnlcs = nil;
                if (!wsnlcs)
                    wsnlcs = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
                
                for (NSString* vp in [vps componentsSeparatedByString:@",\n"]) {
                    NSArray* vpc = [vp componentsSeparatedByString:@"="];
                    if (vpc.count == 1)
                        [b setObject:[[vpc objectAtIndex:0] stringByTrimmingCharactersInSet:wsnlcs] forKey:[[vpc objectAtIndex:0] stringByTrimmingCharactersInSet:wsnlcs]];
                    else if (vpc.count >= 2)
                        [b setObject:[[[vpc subarrayWithRange:NSMakeRange(1, vpc.count-1)] componentsJoinedByString:@"="] stringByTrimmingCharactersInSet:wsnlcs] forKey:[[vpc objectAtIndex:0] stringByTrimmingCharactersInSet:wsnlcs]];
                }
                
                [base setObject:b forKey:cs];
            }
        }
        
        NSMutableDictionary* b = [[[O2DicomPredicateEditorOrderedMutableDictionary alloc] init] autorelease];
        [b setObject:NSLocalizedString(@"empty", nil) forKey:@0];
        [b setObject:NSLocalizedString(@"unread", nil) forKey:@1];
        [b setObject:NSLocalizedString(@"reviewed", nil) forKey:@2];
        [b setObject:NSLocalizedString(@"dictated", nil) forKey:@3];
        [b setObject:NSLocalizedString(@"validated", nil) forKey:@4];
        [b setObject:NSLocalizedString(@"printed", nil) forKey:@5];
        [b setObject:NSLocalizedString(@"distributed", nil) forKey:@6];
        [b setObject:NSLocalizedString(@"archived", nil) forKey:@7];
        [base setObject:b forKey:@"OsiriX StudyStatus"];
        
//        NSLog(@"base: %@", base);
    }
    
    return base;
}

+ (NSDictionary*)codeStringsForTag:(DCMAttributeTag*)tag {
    if (![tag.vr isEqualToString:@"CS"])
        return nil;
    
    NSString* k = tag.name;
    if ([tag isKindOfClass:[O2DicomPredicateEditorDCMAttributeTag class]]) {
        NSString* k2 = [(O2DicomPredicateEditorDCMAttributeTag*)tag cskey];
        if (k2) k = k2;
    }
    
    return [[self base] objectForKey:k];
}

@end
