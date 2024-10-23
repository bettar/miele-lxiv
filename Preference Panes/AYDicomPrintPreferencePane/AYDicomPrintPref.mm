//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original version of this file had no header

#import "AYDicomPrintPref.h"
#import <SecurityInterface/SFAuthorizationView.h>
#import "AYDicomPrintWindowController.h"
#import "alertTransition.h"

@implementation AYDicomPrintPref

- (id) initWithBundle:(NSBundle *)bundle
{
	if (self = [super init])
	{
		NSNib *nib = [[[NSNib alloc] initWithNibNamed: @"AYDicomPrintPref" bundle: nil] autorelease];
		[nib instantiateNibWithOwner:self topLevelObjects: nil];
		
		[self setMainView: [mainWindow contentView]];
		[self mainViewDidLoad];
	}
	
	return self;
}

- (void) dealloc
{
	[m_PrinterDefaults release];

	[super dealloc];
}

- (void) willUnselect
{
	[[[self mainView] window] makeFirstResponder: nil];
}

- (void) awakeFromNib
{
	[AYDicomPrintWindowController updateAllPreferencesFormat];
	
	// select default printer
	NSArray *printer = [m_PrinterController arrangedObjects];

	NSDictionary *printerDict;
	for (int i = 0; i < [printer count]; i++)
	{
		printerDict = [printer objectAtIndex: i];

		if ([[printerDict valueForKey: @"defaultPrinter"] isEqualToString: @"1"])
		{
			[m_PrinterController setSelectionIndex: i];
			break;
		}
	}

	// set printer defaults for undo
	if ([[NSUserDefaults standardUserDefaults] objectForKey: @"AYDicomPrinter"])
	{
		m_PrinterDefaults = [[NSArray arrayWithArray: [[NSUserDefaults standardUserDefaults] objectForKey: @"AYDicomPrinter"]] retain];
	}
}

- (IBAction) saveList: (id) sender
{
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setAllowedFileTypes: @[@"plist"]];
    [sPanel setNameFieldStringValue: NSLocalizedString(@"DICOMPrinters.plist", nil)];

    if ([sPanel runModal] == NSModalResponseOK)
	{
		[[m_PrinterController arrangedObjects] writeToFile:[sPanel filename] atomically: YES];
	}
}

- (IBAction) loadList: (id) sender
{
	NSOpenPanel *sPanel = [NSOpenPanel openPanel];
    [sPanel setAllowedFileTypes: @[@"plist"]];
	if ([sPanel runModal] != NSModalResponseOK)
        return;

    NSArray	*r = [NSArray arrayWithContentsOfFile: [sPanel filename]];
    if (!r)
        return;
    
    if ( NSRunInformationalAlertPanel2(NSLocalizedString(@"Load printers", nil),
                                      NSLocalizedString(@"Should I add or replace the printer list? If you choose 'replace', the current list will be deleted.", nil),
                                      NSLocalizedString(@"Add", nil),
                                      NSLocalizedString(@"Replace", nil),
                                      nil) != NSAlertDefaultReturn2)
    {
        [m_PrinterController removeObjects: [m_PrinterController arrangedObjects]];
    }
    
    [m_PrinterController addObjects: r];
    
    for (int i = 0; i < [[m_PrinterController arrangedObjects] count]; i++)
    {
        NSDictionary	*server = [[m_PrinterController arrangedObjects] objectAtIndex: i];
        
        for (int x = 0; x < [[m_PrinterController arrangedObjects] count]; x++)
        {
            NSDictionary	*c = [[m_PrinterController arrangedObjects] objectAtIndex: x];
            
            if (c != server)
            {
                if ([[server valueForKey:@"host"] isEqualToString: [c valueForKey:@"host"]] &&
                    [[server valueForKey:@"port"] isEqualToString: [c valueForKey:@"port"]])
                    {
                        [m_PrinterController removeObjectAtArrangedObjectIndex: i];
                        i--;
                        x = [[m_PrinterController arrangedObjects] count];
                    }
            }
        }
    }
}

- (IBAction) addPrinter: (id) sender
{
	int printerCount = [[m_PrinterController arrangedObjects] count] + 1;
	NSMutableDictionary *printer = [NSMutableDictionary dictionary];

	// add default printer with default values
	[printer setValue: [NSString stringWithFormat: @"Printer %d", printerCount] forKey: @"printerName"];
	[printer setValue: @"localhost" forKey: @"host"];
	[printer setValue: @"4080" forKey: @"port"];
	[printer setValue: [NSString stringWithFormat: @"Printer_%d", printerCount] forKey: @"aeTitle"];
	
	[printer setValue: @"0" forKey: @"imageDisplayFormatTag"];
	[printer setValue: @"0" forKey: @"borderDensityTag"];
	[printer setValue: @"0" forKey: @"emptyImageDensityTag"];
	[printer setValue: @"0" forKey: @"filmOrientationTag"];
	[printer setValue: @"0" forKey: @"filmDestinationTag"];
	[printer setValue: @"0" forKey: @"magnificationTypeTag"];
	[printer setValue: @"0" forKey: @"trimTag"];
	[printer setValue: @"0" forKey: @"filmSizeTag"];
	[printer setValue: @"" forKey: @"configurationInformation"];
	[printer setValue: @"0" forKey: @"priorityTag"];
	[printer setValue: @"0" forKey: @"mediumTag"];
	[printer setValue: @"1" forKey: @"copies"];
	
	// add new printer & select it
	[m_PrinterController addObject: printer];
	[m_PrinterController setSelectedObjects: [NSArray arrayWithObject: printer]];

	// if it is the first printer added, set it as default
	if ([[m_PrinterController arrangedObjects] count] == 1)
		[self setDefaultPrinter: nil];
}

- (IBAction) setDefaultPrinter: (id) sender
{
	// set new default printer
	NSArray *printer = [m_PrinterController arrangedObjects];

	NSMutableDictionary *printerDict;
	for (int i = 0; i < [printer count]; i++)
	{
		printerDict = [printer objectAtIndex: i];
		[printerDict removeObjectForKey: @"defaultPrinter"];
	}

	printerDict = [m_PrinterController selection];
	[printerDict setValue: @"1" forKey: @"defaultPrinter"];
}

@end
