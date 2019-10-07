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

#import <Foundation/Foundation.h>

// See also querySearchTags in QueryController
enum querySearchTypes {
    searchContains = 0,
    searchStartsWith = 1,
    searchEndsWith = 2,
    searchExactMatch = 3,
    
    // dateSearchTypes
    searchToday = 4,
    searchYesterday = 5,
    searchBefore = 6,
    searchAfter = 7,
    searchWithin = 8,
    searchExactDate = 9,
    
    // dateWithinSearch
    searchWithinToday = 10,
    searchWithinLast2Days,
    searchWithinLastWeek,
    searchWithinLast2Weeks,
    searchWithinLastMonth,
    searchWithinLast2Months,
    searchWithinLast3Months,
    searchWithinLastYear
    };

enum modalities {osiCR = 0,osiCT,osiDX,osiES,osiMG,osiMR,osiNM,osiOT,osiPT,osiRF,osiSC,osiUS,osiXA};
enum studyState {empty = 0, unread, reviewed, dictated, validated, printed, distributed, archived};

/** \brief Query Filter */
@interface QueryFilter : NSObject {
	id _key;
	id _object;
	querySearchTypes _searchType;
}

+ (id)queryFilter;
+ (id)queryFilterWithObject:(id)object ofSearchType:(querySearchTypes)searchType forKey:(id)key;
- (id)initWithObject:(id)object ofSearchType:(querySearchTypes)searchType forKey:(id)key;

- (id) key;
- (id) object;
- (querySearchTypes) searchType;
- (NSString *)filteredValue;

- (void)setKey:(id)key;
- (void)setObject:(id)object;
- (void)setSearchType:(querySearchTypes)searchType;

- (NSString *)withinDateString;


@end
