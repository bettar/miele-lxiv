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

#import "DicomImageDCMTKCategory.h"

#include "dcmtk/ofstd/ofstream.h"
#include "dcmtk/dcmsr/dsrdoc.h"
#include "dcmtk/dcmdata/dcuid.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmsr/dsrtypes.h"
#include "dcmtk/dcmsr/dsrimgtn.h"

@implementation Dicom_Image (DicomImageDCMTKCategory)

- (NSString*) keyObjectType
{
	NSString *type = nil;
	DcmFileFormat fileformat;
	DSRDocument *doc = new DSRDocument();
	OFCondition status = fileformat.loadFile([[self completePath] UTF8String]);
	if (status.good())
		status = doc->read(*fileformat.getDataset());
	if (status.good())
	{
		OFString codeMeaning = doc->getTree().getCurrentContentItem().getConceptName().getCodeMeaning();
		type = [NSString stringWithUTF8String:codeMeaning.c_str()];
	}
	delete doc;
	return type;
}

- (NSArray*) referencedObjects
{
	NSMutableArray *references = [NSMutableArray array];
	DcmFileFormat fileformat;
	DSRDocument *doc = new DSRDocument();
	OFCondition status = fileformat.loadFile([[self completePath] UTF8String]);
	if (status.good())
		status = doc->read(*fileformat.getDataset());
    
	if (status.good())
	{
		DSRDocumentTreeNode *node = NULL; 
		//DSRDocumentTree  *tree = doc->getTree();
		/* iterate over all nodes */ 
        do {
#if 0 // @@@ original TODO: getNode is a protected member of DSRDocumentTreeNode
            node = OFstatic_cast(DSRDocumentTreeNode *, doc->getTree().getNode());
//#else
//            DSRDocumentTree &pTree = doc->getTree();
//            DSRDocumentTreeNode *pNode = DSRTreeNodeCursor::pTree.getNode();
#endif
            if (node->getValueType() == DSRTypes::VT_Image)
			{
				//image node get SOPCInstance
				DSRImageTreeNode *imageNode = OFstatic_cast(DSRImageTreeNode *, node);
				OFString sopInstance = imageNode->getSOPInstanceUID();
				NSString *uid = [NSString stringWithUTF8String:sopInstance.c_str()];
				if (uid)
					[references addObject:uid];
			}
        } while (doc->getTree().iterate()); 
	}
	delete doc;
	return references;
}



@end
