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

#import <DCM/DCMCharacterSet.h>

#define NUM_ENCODINGS        10

char* DCMreplaceInvalidCharacter( char* str ) {
	long i = strlen( str);
	
	while( i-- >0 )	{
		if( str[i] == '/') str[i] = '-';
		if( str[i] == '^') str[i] = ' ';
	}
	
	i = strlen( str);
	while( --i > 0 ) {
		if( str[i] ==' ') str[i] = 0;
		else i = 0;
	}
	
	return str;
}

@implementation DCMCharacterSet

@synthesize encoding, encodings, characterSet = _characterSet;

+ (NSString*) NSreplaceBadCharacter: (NSString*) str
{
	if (str == nil)
        return nil;
	
	NSMutableString	*mutable1 = [NSMutableString stringWithString: str];
	
//	[mutable1 replaceOccurrencesOfString:@"^" withString:@" " options:0 range:NSMakeRange(0, [mutable1 length])];
//	[mutable1 replaceOccurrencesOfString:@"/" withString:@"-" options:0 range:NSMakeRange(0, [mutable1 length])];
	[mutable1 replaceOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0, [mutable1 length])];
	[mutable1 replaceOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange(0, [mutable1 length])];
	[mutable1 replaceOccurrencesOfString:@"\"" withString:@"'" options:0 range:NSMakeRange(0, [mutable1 length])];
	
	NSUInteger i = [mutable1 length];
	while( --i > 0)
	{
		if( [mutable1 characterAtIndex: i]==' ')
            [mutable1 deleteCharactersInRange: NSMakeRange( i, 1)];
		else
            i = 0;
	}
	
	return mutable1;
}

// Based on DCMTK 3.6.5 function DcmSpecificCharacterSet::convertString()
// Used in DCM framework
// targets miele and decompress both use DCM
// TODO: Use the DCM framework version instead
+ (NSString *) stringWithBytes:(char *) str
                        length:(const size_t) length
                     encodings:(NSStringEncoding*) encodings
{
	if (!str)
        return nil;
    
    NSUInteger fromLength;
    
    if (length > 0) {
        fromLength = length;
    }
	else {
        NSLog(@"***** warning DCMCharacterSet stringWithBytes, length == 0, use C String length");
        fromLength = strlen( str);
    }

    NSMutableString *result = [NSMutableString string];
    BOOL checkPNDelimiters = YES;
    size_t pos = 0;
    // some (extended) character sets use more than 1 byte per character
    // (however, the default character set always uses a single byte)
    unsigned char bytesPerChar = 1;
    char *firstChar = str;
    char *currentChar = str;
    BOOL isFirstGroup = NO; // if delimiters contains '=' -> patient name
    int escLength = 0;
    // initially, use the default descriptor
    NSStringEncoding currentEncoding = encodings[ 0];
    // iterate over all characters of the string
    while (pos < fromLength)
    {
        char c0 = *currentChar++;
        // check for characters ESC, HT, LF, FF, CR or any other specified delimiter
        BOOL isEscape = (c0 == '\033');
        BOOL isPNDelimiter = ((c0 == '^') || (c0 == '=')) && checkPNDelimiters;
        BOOL isDelimiter = (c0 == '\011') || (c0 == '\012') || (c0 == '\014') || (c0 == '\015') || isPNDelimiter;
        
        if (isEscape || isDelimiter)
        {
            // convert the sub-string (before the delimiter) with the current character set
            long int convertLength = currentChar - firstChar - 1;
            if (convertLength - (escLength+1) >= 0)
            {
                NSString *s = [[[NSString alloc] initWithBytes: firstChar
                                                        length: convertLength
                                                      encoding: currentEncoding] autorelease];
                if (s)
                    [result appendString: s];
            }
            
            // check whether this was the first component group of a PN value
            if (isDelimiter && (c0 == '='))
                isFirstGroup = NO;
        }
        
        // the ESC character is used to explicitly switch between character sets
        if (isEscape)
        {
            // report a warning as this is a violation of DICOM PS 3.5 Section 6.2.1
            if (isFirstGroup)
            {
                NSLog( @"DcmSpecificCharacterSet: Escape sequences shall not be used in the first component group of a Person Name (PN), using them anyway)");
            }
            
            // we need at least two more characters to determine the new character set
            escLength = 2;
            if (pos + escLength < fromLength)
            {
                NSString *key = nil;
                char c1 = *currentChar++;
                char c2 = *currentChar++;
                char c3 = '\0';
                if ((c1 == 0x28) && (c2 == 0x42))       // ASCII
                    key = @"ISO 2022 IR 6";
                else if ((c1 == 0x2d) && (c2 == 0x41))  // Latin alphabet No. 1
                    key = @"ISO 2022 IR 100";
                else if ((c1 == 0x2d) && (c2 == 0x42))  // Latin alphabet No. 2
                    key = @"ISO 2022 IR 101";
                else if ((c1 == 0x2d) && (c2 == 0x43))  // Latin alphabet No. 3
                    key = @"ISO 2022 IR 109";
                else if ((c1 == 0x2d) && (c2 == 0x44))  // Latin alphabet No. 4
                    key = @"ISO 2022 IR 110";
                else if ((c1 == 0x2d) && (c2 == 0x4c))  // Cyrillic
                    key = @"ISO 2022 IR 144";
                else if ((c1 == 0x2d) && (c2 == 0x47))  // Arabic
                    key = @"ISO 2022 IR 127";
                else if ((c1 == 0x2d) && (c2 == 0x46))  // Greek
                    key = @"ISO 2022 IR 126";
                else if ((c1 == 0x2d) && (c2 == 0x48))  // Hebrew
                    key = @"ISO 2022 IR 138";
                else if ((c1 == 0x2d) && (c2 == 0x4d))  // Latin alphabet No. 5
                    key = @"ISO 2022 IR 148";
                else if ((c1 == 0x29) && (c2 == 0x49))  // Japanese
                    key = @"ISO 2022 IR 13";
                else if ((c1 == 0x28) && (c2 == 0x4a))  // Japanese - is this really correct?
                    key = @"ISO 2022 IR 13";
                else if ((c1 == 0x2d) && (c2 == 0x54))  // Thai
                    key = @"ISO 2022 IR 166";
                else if ((c1 == 0x24) && (c2 == 0x42))  // Japanese (multi-byte)
                    key = @"ISO 2022 IR 87";
                else if ((c1 == 0x24) && (c2 == 0x28))  // Japanese (multi-byte)
                {
                    escLength = 3;
                    // do we still have another character in the string?
                    if (pos + escLength < fromLength)
                    {
                        c3 = *currentChar++;
                        if (c3 == 0x44)
                            key = @"ISO 2022 IR 159";
                    }
                }
                else if ((c1 == 0x24) && (c2 == 0x29)) // Korean (multi-byte)
                {
                    escLength = 3;
                    // do we still have another character in the string?
                    if (pos + escLength < fromLength)
                    {
                        c3 = *currentChar++;
                        if (c3 == 0x43)                 // Korean (multi-byte)
                            key = @"ISO 2022 IR 149";
                        else if (c3 == 0x41)            // Simplified Chinese (multi-byte)
                            key = @"ISO 2022 IR 58";
                    }
                }
                
                // check whether a valid escape sequence has been found
                if (key.length == 0) {
                    if (escLength == 3)
                        NSLog( @"Cannot convert character set: Illegal escape sequence 'ESC %x %x %x' found", c1, c2, c3);
                    else
                        NSLog( @"Cannot convert character set: Illegal escape sequence 'ESC %x %x' found", c1, c2);
                }
                else
                {
                    currentEncoding = [DCMCharacterSet encodingForDICOMCharacterSet: key];
#ifndef NDEBUG
                    BOOL found = NO;
                    for (int j = 0; j < NUM_ENCODINGS; j++)
                        if (currentEncoding == encodings[j]) {
                            found = YES;
                            break;
                        }
                    
                    if (found == NO)
                        NSLog(@"*** encoding not found in declared SpecificCharacterSet (0008,0005)");
#endif
                    // special case: these Japanese character sets replace the ASCII part (G0 code area),
                    // so according to DICOM PS 3.5 Section 6.2.1.2 an explicit switch to the default is required
                    checkPNDelimiters = (![key isEqualToString: @"ISO 2022 IR 87"]) &&
                    (![key isEqualToString: @"ISO 2022 IR 159"]);
                    
                    // determine number of bytes per character (used by the selected character set)
                    if ([key isEqualToString: @"ISO 2022 IR 87"] ||
                        [key isEqualToString: @"ISO 2022 IR 159"] ||
                        [key isEqualToString: @"ISO 2022 IR 58"])
                    {
                        //NSLog(@"Now using 2 bytes per character");
                        bytesPerChar = 2;
                    }
                    else if ([key isEqualToString: @"ISO 2022 IR 149"])
                    {
                        //NSLog(@"Now using 1 or 2 bytes per character");
                        bytesPerChar = 0;      // special handling for single- and multi-byte
                    }
                    else {
                        //NSLog(@"Now using 1 byte per character");
                        bytesPerChar = 1;
                    }
                    
                    if (checkPNDelimiters)
                        firstChar = currentChar; // do not copy the escape sequence to the output
                    else
                        firstChar = currentChar - (escLength+1);
                }
                
                pos += escLength;
                
                if( checkPNDelimiters)
                    escLength = 0;
            }
            
            if (pos >= fromLength)
                NSLog( @"incomplete sequence");
        }
        // the HT, LF, FF, CR character or other delimiters (depending on the VR) also cause a switch
        else if (isDelimiter)
        {
            [result appendFormat: @"%c", c0];
            
            if (currentEncoding != encodings[ 0])
            {
                NSLog(@"Switching back to the default character set (because a delimiter was found)");
                currentEncoding = encodings[ 0];
                checkPNDelimiters = YES;
            }
            // start new sub-string after delimiter
            firstChar = currentChar;
        }
#if 1
        // skip remaining bytes of current character (if any)
        else if (bytesPerChar != 1)
        {
            const size_t skipBytes = (bytesPerChar > 0) ? (bytesPerChar - 1) : ((c0 & 0x80) ? 1 : 0);
            if (pos + skipBytes < fromLength)
                currentChar += skipBytes;
            pos += skipBytes;
        }
#endif
        ++pos;
    }
    
    // convert any remaining characters from the input string
    {
        long convertLength = currentChar - firstChar;
        if (convertLength > 0)
        {
            if (firstChar + convertLength <= str + fromLength &&
                (convertLength - (escLength+1) >= 0))
            {
                NSString *s = [[[NSString alloc] initWithBytes: firstChar
                                                        length: convertLength
                                                      encoding: currentEncoding] autorelease];
                
                if (s)
                    [result appendString: s];
            }
        }
    }

    return result;
}

+ (NSStringEncoding)encodingForDICOMCharacterSet:(NSString *)characterSet
{
	NSStringEncoding encoding = NSISOLatin1StringEncoding;
	
	if (characterSet.length == 0)
        return encoding;
	
	characterSet = [characterSet stringByReplacingOccurrencesOfString:@"-" withString:@" "];
	characterSet = [characterSet stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    characterSet = [characterSet stringByReplacingOccurrencesOfString:@"ISO 2022" withString:@"ISO"];
	
	if	   ( [characterSet isEqualToString:@"ISO IR 100"]) encoding = NSISOLatin1StringEncoding;
	else if( [characterSet isEqualToString:@"ISO IR 127"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinArabic);
    else if( [characterSet isEqualToString:@"ISO IR 148"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin5);
	else if( [characterSet isEqualToString:@"ISO IR 101"]) encoding = NSISOLatin2StringEncoding;
	else if( [characterSet isEqualToString:@"ISO IR 109"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin3);
	else if( [characterSet isEqualToString:@"ISO IR 110"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin4);
	else if( [characterSet isEqualToString:@"ISO IR 144"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinCyrillic);
	else if( [characterSet isEqualToString:@"ISO IR 126"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinGreek);
	else if( [characterSet isEqualToString:@"ISO IR 138"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinHebrew);
    else if( [characterSet isEqualToString:@"ISO IR 166"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinThai);
	else if( [characterSet isEqualToString:@"GB18030"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingGB_18030_2000);
	else if( [characterSet isEqualToString:@"ISO IR 192"]) encoding = NSUTF8StringEncoding;
	else if( [characterSet isEqualToString:@"ISO IR 13"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingMacJapanese);
	else if( [characterSet isEqualToString:@"ISO IR 6"])	encoding = NSISOLatin1StringEncoding;
    else if( [characterSet isEqualToString:@"ISO IR 13"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingMacJapanese);
    else if( [characterSet isEqualToString:@"ISO IR 58"])	encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISO_2022_CN);
    else if( [characterSet isEqualToString:@"ISO IR 87"]) encoding = NSISO2022JPStringEncoding;
    else if( [characterSet isEqualToString:@"ISO IR 149"]) encoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingEUC_KR);
    else if( [characterSet isEqualToString:@"ISO IR 6"])	encoding = NSISOLatin1StringEncoding;
	else if( [characterSet isEqualToString:@"UTF 8"])	encoding = NSUTF8StringEncoding;
	else
	{
		NSLog(@"** DICOMTONSString encoding not found: %@", characterSet);
		
        if( characterSet.length < 50)
        {
            NSArray *multipleEncoding = [characterSet componentsSeparatedByString:@"\\"];
            if( [multipleEncoding count] > 1)
            {
                NSLog( @"**** error: multiple encoding in %s : %@", __PRETTY_FUNCTION__, characterSet);
                return [DCMCharacterSet encodingForDICOMCharacterSet: [multipleEncoding objectAtIndex: 0]];
            }
        }
	}

    return encoding;
}

- (id)initWithCode:(NSString *)characterSet
{
	if (self = [super init])
	{
		_characterSet = [characterSet retain];
		encoding = NSISOLatin1StringEncoding;
		
		if (!encodings)
			encodings = (NSStringEncoding *)malloc(NUM_ENCODINGS * sizeof( NSStringEncoding));
		
        encodings[0] = NSISOLatin1StringEncoding;
		for (int i = 1; i < NUM_ENCODINGS; i++)
            encodings[i] = NSUTF8StringEncoding;
		
		NSArray *e = [characterSet componentsSeparatedByString: @"\\"];
		
		for (int z = 0; z < [e count] ; z++)
		{
			if (z < NUM_ENCODINGS)
				encodings[ z] = [DCMCharacterSet encodingForDICOMCharacterSet: [e objectAtIndex: z]];
			else
				NSLog(@"Encoding number >= %d ???", NUM_ENCODINGS);
		}

        encoding = encodings[0];
	}

    return self;
}

- (id)initWithCharacterSet:(DCMCharacterSet *)characterSet
{
	return [self initWithCode:[characterSet characterSet]];
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[DCMCharacterSet allocWithZone:zone] initWithCharacterSet:self];
}

- (void)dealloc
{
	if( encodings) free( encodings);
	[_characterSet release];
	[super dealloc];
}

- (NSString*) description
{
	return _characterSet;
}
@end
