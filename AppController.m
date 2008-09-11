//
//  AppController.m
//  EyePatch
//
//  Created by Mike Metzger on 9/7/08.
//  Copyright 2008 Techplay.net. All rights reserved.
//

#import "AppController.h"
#import <Security/Security.h>

static AuthorizationRef authorizationRef = NULL;

@implementation AppController

- (void)dealloc
{
	[statusItem release];
	[enabledMenuIcon release];
	[disabledMenuIcon release];
	[actionMenuItem release];
	[files release];
	[super dealloc];
}

- (void)awakeFromNib
{
	// Create the list of files we'll be checking / modifying permissions of for iSight status
	files = [[NSArray arrayWithObjects:@"/System/Library/QuickTime/QuickTimeUSBVDCDigitizer.component/Contents/MacOS/QuickTimeUSBVDCDigitizer",
			  @"/System/Library/PrivateFrameworks/CoreMediaIOServicesPrivate.framework/Versions/A/Resources/VDC.plugin/Contents/MacOS/VDC", nil] retain];
	
	// Load the icons from the bundle resources
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *enabledIconPath = [bundle pathForResource:@"eyeicon" ofType:@"gif"];
	NSString *disabledIconPath = [bundle pathForResource:@"eyepatch" ofType:@"gif"];
	
	enabledMenuIcon = [[NSImage alloc] initWithContentsOfFile:enabledIconPath];
	disabledMenuIcon = [[NSImage alloc] initWithContentsOfFile:disabledIconPath];
	
	
	// Get a status item for the Menu Bar and configure appropriately
	statusItem = [[[NSStatusBar systemStatusBar]
				   statusItemWithLength:NSVariableStatusItemLength]
				  retain];
	[statusItem setHighlightMode:YES];
	
	[statusItem setTitle:[NSString stringWithString:@""]];	
	
	[statusItem setEnabled:YES];
	[statusItem setToolTip:@"iSightStatus"];
	
	[statusItem setMenu:theMenu];
	
	// Menu item for the state of the iSight Camera
	statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
	[statusMenuItem setTarget:self];
	
	[theMenu insertItem:statusMenuItem atIndex:0];
	
	// Menu item for the appropriate action to use on the iSight Camera (enable or disable)
	actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
	[actionMenuItem setTarget:self];
	
	[theMenu insertItem:actionMenuItem atIndex:2];
	
	
	[self updateiSightStatus:nil];
	
}

- (void)changeiSightPermissions:(NSArray *)fileList permissions:(NSString *)permissionString
{
	
	// This is all pretty ugly and doesn't really work the way I want it to.  This is currently using the AuthorizationCreate / AuthorizationExecuteWithPrivileges which is not recommended for 
	// most tools.  It appears the preferred way to do this is with the "BetterAuthorizationSample" but I haven't been able to sort through all that yet.  The gist is that this method should
	// likely be moved into its own tool that is handled by launchd.  At the moment, I'm not sure how installation / etc works so that will be for later.  If so, will likely change the code to use 
	// NSFileManager with setAttributes instead of calling chmod externally - it would've been beautiful here but for some reason there's not an easy (or even possible?) way to request admin, 
	// run a method, and drop admin.
	//
	// Instead, we have the Carbon / C level security authentication stuff here... I *really* need to brush up on my standard C coding.
	// 
	
	// Create a char array with the path to the chmod tool
	char * chmodPath = (char *)[@"/bin/chmod" UTF8String];
	
	
	OSStatus status;
	
	// Check for an active authorization reference - need to add some preference capabilities in here - ie, how long to maintain the authorization (5 min, 10 min, forever?)
	
	if (authorizationRef == NULL)
	{
		NSLog(@"No authorization - about to authorize");
		
		// Create a temporary auth to check for status later on - not doing it this way makes error handling even more difficult than before
		status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
		
		// Create a list of authorizationitems / rights / etc.  This is all part of the general insanity of this API.  
		// Best reference to the whole thing: http://developer.apple.com/documentation/Security/Conceptual/authorization_concepts/03authtasks/chapter_3_section_2.html#//apple_ref/doc/uid/TP30000995-CH206-BCIGEHDI
		//
		AuthorizationItem myItems[1];
		myItems[0].name = kAuthorizationRightExecute;
		myItems[0].value = chmodPath;
		myItems[0].valueLength = strlen(chmodPath);
		myItems[0].flags = 0;
		
		AuthorizationRights myRights;
		myRights.count = sizeof(myItems) / sizeof(myItems[0]);
		myRights.items = myItems;
		
		AuthorizationFlags myFlags;
		myFlags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
		
		status = AuthorizationCreate(&myRights, kAuthorizationEmptyEnvironment, myFlags, &authorizationRef);
		
	}
	else
	{
		NSLog(@"Already authorized - Should not hit this state as authorization is dropped immediately after completeing method call");
		status = noErr;
	}
	
	// Verify we actually have authorization
	if (status != noErr)
	{
		NSLog(@"Could not get authorization, failing.");
		return;
	}
	
	// Run chmod on both files in the list seperately.  For whatever reason running the commands back to back fails on the 2nd file - this is more general, in case Apple decides to create more drivers for the iSight.
	//
	// 
	for (NSString *file in fileList)
	{
		char * args[2];
		args[0] = (char *)[permissionString UTF8String];
		args[1] = (char *)[file UTF8String];
		args[2] = NULL;
		
		status = AuthorizationExecuteWithPrivileges(authorizationRef, chmodPath, 0, args, NULL);
		NSLog(@"Trying to exectute %s %s %s", chmodPath, args[0], args[1]);
		
		if (status != noErr)
		{
			NSLog(@"Error changing permissions on %s - failing: %d", args[1], status);
		}
		else
		{
			NSLog(@"Permissions changed on %s", args[1]);
		}
	}
	
	// Free the Authorization Credentials
	NSLog(@"Dropping privileged authorization");
	AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
	authorizationRef = NULL;
}


- (IBAction)enableiSight:(id)sender
{
	NSLog(@"In Enable iSight");
	
	// Change permissions to the unix equivalent of -r-xr--r--
	[self changeiSightPermissions:files permissions:@"0544"];

	NSLog(@"Task finished - updating status");
	
	[self updateiSightStatus:nil];
}

- (IBAction)disableiSight:(id)sender
{
	NSLog(@"In Disable iSight");
	
	// Change permissions to the unix equivalent of ----------
	[self changeiSightPermissions:files permissions:@"0000"];
		
	NSLog(@"Task finished - updating status");
	
	[self updateiSightStatus:nil];
	
}

- (IBAction)updateiSightStatus:(id)sender
{
	// Get the default File Manager
	NSFileManager *manager = [NSFileManager defaultManager];
	
	BOOL isCameraEnabled = NO;
	
	// Equivalent for a POSIX file with no permissions
	NSString *noPermission = @"0";
	
	// Get all the file attributes for each file in the list
	for (NSString *filePath in files)
	{
		NSDictionary *fileAttributes = [manager attributesOfItemAtPath:filePath error:nil];
		
		// Get the POSIX file permissions
		unsigned long perms = [[fileAttributes objectForKey:NSFilePosixPermissions] unsignedLongValue];
		
		// Convert to the standard Octal permissions structure - mainly interested in validating that the permissions are 0.  If anything else, we will assume that the iSight drivers are enabled.
		NSString *permsInOctal = [NSString stringWithFormat:@"%O", perms];
		
		NSLog(@"%@\nOctal Permissions: %@\nUnsigned Permissions: %@\n\n", filePath, permsInOctal, [fileAttributes objectForKey:NSFilePosixPermissions]);
		
		// Check if the permissions are anything other than 0 - if so, assume the camera drivers are enabled
		if ([noPermission compare:permsInOctal] != 0)
		{
			isCameraEnabled = YES;
		}
	}
		
	NSLog(@"Camera Enabled: %d", isCameraEnabled);
	
	// Modify status icon items based on iSight state
	if (isCameraEnabled)
	{
		[statusMenuItem setTitle:[NSString stringWithString:@"iSight Status: Enabled"]];
		[statusItem setImage:enabledMenuIcon];
		[actionMenuItem setTitle:[NSString stringWithString:@"Disable iSight"]];
		[actionMenuItem setAction:@selector(disableiSight:)];
	} else {
		[statusMenuItem setTitle:[NSString stringWithString:@"iSight Status: Disabled"]];
		[statusItem setImage:disabledMenuIcon];
		[actionMenuItem setTitle:[NSString stringWithString:@"Enable iSight"]];
		[actionMenuItem setAction:@selector(enableiSight:)];
	}
}

	
@end
