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

#include "dcmtk/config/osconfig.h"

#import "PreferencesWindowController+DCMTK.h"
#import "CIADICOMField.h"

#include "mdfconen.h"

#include "dcmtk/dcmdata/dcvrsl.h"
#include "dcmtk/ofstd/ofcast.h"
#include "dcmtk/ofstd/ofstd.h"
#include "dcmtk/dcmdata/dctk.h"
#include "dcmtk/dcmdata/dcuid.h"

#include <cstdio>
#include <ctime>
#include "dcmtk/ofstd/ofstdinc.h"

@implementation PreferencesWindowController (DCMTK)

- (NSArray*) prepareDICOMFieldsArrays
{
	DcmDictEntry* e = NULL;
	DcmDataDictionary& globalDataDict = dcmDataDict.wrlock();
	
	DcmDictEntryList list;
    DcmHashDictIterator iter(globalDataDict.normalBegin());
    for ( int x = 0; x < globalDataDict.numberOfNormalTagEntries(); ++iter, x++)
    {
        if ((*iter)->getPrivateCreator() == NULL) // exclude private tags
        {
          e = new DcmDictEntry(*(*iter));
          list.insertAndReplace(e);
        }
    }
	
	NSMutableArray *DICOMFieldsArray = [NSMutableArray array];
	
    /* output the list contents */
    DcmDictEntryListIterator listIter(list.begin());
    DcmDictEntryListIterator listLast(list.end());
    for (; listIter != listLast; ++listIter)
    {
		e = *listIter;
		
		if ( e->getGroup() > 0)
		{
//			NSString	*s = [NSString stringWithFormat:@"(0x%04x,0x%04x) %s", e->getGroup(), e->getElement(), e->getTagName()];
					
//			[DICOMFieldsTitlesArray addObject: s];
//			[DICOMFieldsArray addObject:[NSString stringWithFormat:@"%s",e->getTagName()]];
//			
//			[DICOMGroupsArray addObject:[NSNumber numberWithInt:e->getGroup()]];
			
			CIADICOMField *dicomField = [[CIADICOMField alloc] initWithGroup:e->getGroup() element:e->getElement() name:[NSString stringWithFormat:@"%s",e->getTagName()]];
			[DICOMFieldsArray addObject:dicomField];
			[dicomField release];
		}
    }
	
	dcmDataDict.rdunlock();
	
	return DICOMFieldsArray;
}

@end
