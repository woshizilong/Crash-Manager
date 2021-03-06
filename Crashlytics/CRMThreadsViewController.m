//
//  CRMThreadsTableViewController.m
//  Crash Manager
//
//  Created by Sasha Zats on 12/25/13.
//  Copyright (c) 2013 Sasha Zats. All rights reserved.
//

#import "CRMThreadsViewController.h"

#import "CRMIncident.h"
#import "CRMIncident_Session+Crashlytics.h"
#import <SHAlertViewBlocks/SHAlertViewBlocks.h>

@interface CRMThreadsViewController ()

@property (nonatomic, weak) CRMSessionEvent *event;
@property (nonatomic, weak) CRMSessionExecution *execution;
@property (nonatomic, weak) PBArray *threads;
@property (nonatomic, weak) CRMSessionThread *crashedThread;

@end

@implementation CRMThreadsViewController
@synthesize session = _session;


#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    @weakify(self);
    [self.sessionChangedSignal subscribeNext:^(CRMSession *session) {
        @strongify(self);

    	if (![session.events count]) {
            self.threads = nil;
            self.execution = nil;
            self.event = nil;
            self.crashedThread = nil;
        } else {
            self.event = [session lastEvent];
            self.execution = self.event.app.execution;
            self.threads = self.execution.threads;
            self.crashedThread = [self.session crashedThread];
        }
        
        [self.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self.threads count];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
	CRMSessionThread *thread = [self.threads objectAtIndex:section];
	return [thread.frames count];
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
	
	CRMSessionThread *thread = [self.threads objectAtIndex:section];
	BOOL isCrashedThread = (self.crashedThread == thread);
	NSString *crashedSymbol = isCrashedThread ? @"★ " : @"";
	NSString *threadName = [thread.name length] ? thread.name : [NSString stringWithFormat:@"Thread #%u", section];
	NSString *crashSignal = isCrashedThread ? [NSString stringWithFormat:@"\n%@ %@ at 0x%x", self.event.app.execution.signal.name, self.event.app.execution.signal.code, self.event.app.execution.signal.address] : @"";
	return [NSString stringWithFormat:@"%@%@%@", crashedSymbol, threadName, crashSignal];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ThreadFrameCellIdentifier"
															forIndexPath:indexPath];
	
	CRMSessionThread *thread = [self.threads objectAtIndex:indexPath.section];
	CRMSessionFrame *frame = [thread.frames objectAtIndex:indexPath.row];
	CRMSessionBinaryImage *correspondingBinaryImage = [self.session binaryImageForAddress:frame.pc + frame.offset];
	
	NSString *binaryName = correspondingBinaryImage.name ?: @"";
    if (correspondingBinaryImage.name) {
        NSURL *binaryImageURL = [NSURL fileURLWithPath:correspondingBinaryImage.name];
        if (binaryImageURL) {
            binaryName = [binaryImageURL lastPathComponent];
        }
        if (frame.offset) {
            binaryName = [binaryName stringByAppendingFormat:@" + %lu", frame.offset];
        }
    }
	
	BOOL isDeveloperCode = (frame.importance & CRMIncident_FrameImportanceInDeveloperCode) != 0;
	BOOL isCrashedFrame = (frame.importance & CRMIncident_FrameImportanceLikelyLeadToCrash) != 0;
	UIColor *color = isCrashedFrame ? [UIColor blackColor] : [UIColor lightGrayColor];
	cell.textLabel.font = isDeveloperCode ? [UIFont boldSystemFontOfSize:18] : [UIFont systemFontOfSize:18];
	cell.textLabel.textColor = color;

	cell.textLabel.text = frame.symbol;
	cell.detailTextLabel.text = binaryName;

	return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UIAlertView *alert = [UIAlertView SH_alertViewWithTitle:cell.detailTextLabel.text
												withMessage:cell.textLabel.text];
	[alert SH_addButtonWithTitle:@"Copy" withBlock:^(NSInteger theButtonIndex) {
		[[UIPasteboard generalPasteboard] setString:[NSString stringWithFormat:@"%@ %@", cell.detailTextLabel.text, cell.textLabel.text]];
	}];
	[alert SH_addButtonCancelWithTitle:@"Cancel" withBlock:nil];
	[alert show];
}

@end
