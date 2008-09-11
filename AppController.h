//
//  AppController.h
//  EyePatch
//
//  Created by Mike Metzger on 9/7/08.
//  Copyright 2008 Techplay.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppController : NSObject {
	NSStatusItem *statusItem;
	NSImage *enabledMenuIcon;
	NSImage *disabledMenuIcon;
	NSArray *files;
	IBOutlet NSMenu *theMenu;
	NSMenuItem *statusMenuItem;
	NSMenuItem *actionMenuItem;
}

- (IBAction)updateiSightStatus:(id)sender;

- (IBAction)enableiSight:(id)sender;

- (IBAction)disableiSight:(id)sender;

@end
