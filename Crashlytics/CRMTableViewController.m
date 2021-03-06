//
//  CRMTableViewController.m
//  Crash Manager
//
//  Created by Sasha Zats on 12/7/13.
//  Copyright (c) 2013 Sasha Zats. All rights reserved.
//

#import "CRMTableViewController.h"

#import "CRMAccount.h"
#import "CRMOrganization.h"
#import "UIViewController+OpenSource.h"
#import "CRMAnalyticsController.h"

@interface CRMTableViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSMutableIndexSet *deletedSections;
@property (nonatomic, strong) NSMutableIndexSet *insertedSections;

@property (nonatomic, strong) NSMutableArray *deletedIndexPaths;
@property (nonatomic, strong) NSMutableArray *insertedIndexPaths;
@property (nonatomic, strong) NSMutableArray *updatedIndexPaths;

@end

@implementation CRMTableViewController

#pragma mark - Public

- (BOOL)isFirstRowInSectionAtIndexPath:(NSIndexPath *)indexPath {
	indexPath = [self coreDataIndexPathForDisplayIndexPath:indexPath];
	if ([self.fetchedResultsController.sections count] <= indexPath.section) {
		return NO;
	}
	return indexPath.row == 0;
}

- (BOOL)isLastRowInSectionAtIndexPath:(NSIndexPath *)indexPath {
	indexPath = [self coreDataIndexPathForDisplayIndexPath:indexPath];
	if ([self.fetchedResultsController.sections count] <= indexPath.section) {
		return NO;
	}
	id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[indexPath.section];
	return indexPath.row == sectionInfo.numberOfObjects - 1;
}

- (BOOL)isOnlyRowInSectionAtIndexPath:(NSIndexPath *)indexPath {
	indexPath = [self coreDataIndexPathForDisplayIndexPath:indexPath];
	if ([self.fetchedResultsController.sections count] <= indexPath.section) {
		return NO;
	}
	id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[indexPath.section];
	return (indexPath.row == 0 &&
			indexPath.row == sectionInfo.numberOfObjects - 1);
	
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self crm_exposeSource];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
		
	self.fetchedResultsController.delegate = self;
	[self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	[[CRMAnalyticsController sharedInstance] trackViewController:self];

    RACSignal *viewWillDisappear = [self rac_signalForSelector:@selector(viewWillDisappear:)];
	[[[[[CRMAccount activeAccountChangedSignal] takeUntil:viewWillDisappear] distinctUntilChanged] filter:^BOOL(CRMAccount *account) {
		return ![account canCreateSession];
	}] subscribeNext:^(CRMAccount *account) {
		UINavigationController *loginNavigationViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"login"];
		[self presentViewController:loginNavigationViewController
						   animated:YES
						 completion:nil];
	}];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	
	self.fetchedResultsController.delegate = nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[[self coreDataSectionForDisplaySection:section]];
	return sectionInfo.numberOfObjects;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
	if (!self.insertedIndexPaths) {
		self.insertedIndexPaths = [NSMutableArray array];
		self.deletedIndexPaths = [NSMutableArray array];
		self.updatedIndexPaths = [NSMutableArray array];
		
		self.insertedSections = [NSMutableIndexSet indexSet];
		self.deletedSections = [NSMutableIndexSet indexSet];
	}
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
		   atIndex:(NSUInteger)sectionIndex
	 forChangeType:(NSFetchedResultsChangeType)type {
	switch (type) {
		case NSFetchedResultsChangeDelete:
			[self.deletedSections addIndex:[self coreDataSectionForDisplaySection:sectionIndex]];
			break;
		case NSFetchedResultsChangeInsert: {
			[self.insertedSections addIndex:[self coreDataSectionForDisplaySection:sectionIndex]];
			break;
		}
	}
	
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
	   atIndexPath:(NSIndexPath *)indexPath
	 forChangeType:(NSFetchedResultsChangeType)type
	  newIndexPath:(NSIndexPath *)newIndexPath {
	switch (type) {
		case NSFetchedResultsChangeDelete: {
			if (![self.deletedSections containsIndex:[self coreDataIndexPathForDisplayIndexPath:indexPath].section]) {
				[self.deletedIndexPaths addObject:[self coreDataIndexPathForDisplayIndexPath:indexPath]];
			}
			break;
		}
			
		case NSFetchedResultsChangeInsert: {
			if (![self.insertedSections containsIndex:[self coreDataIndexPathForDisplayIndexPath:newIndexPath].section]) {
				[self.insertedIndexPaths addObject:[self coreDataIndexPathForDisplayIndexPath:newIndexPath]];
			}
			break;
		}
			
		case NSFetchedResultsChangeUpdate: {
			[self.updatedIndexPaths addObject:[self coreDataIndexPathForDisplayIndexPath:indexPath]];
			break;
		}
			
		case NSFetchedResultsChangeMove: {
			[self.deletedIndexPaths addObject:[self coreDataIndexPathForDisplayIndexPath:indexPath]];
			[self.insertedIndexPaths addObject:[self coreDataIndexPathForDisplayIndexPath:newIndexPath]];
			break;
		}
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
	[self.tableView beginUpdates];
	
	[self.tableView insertSections:self.insertedSections
				  withRowAnimation:UITableViewRowAnimationTop];
	[self.tableView deleteSections:self.deletedSections
				  withRowAnimation:UITableViewRowAnimationTop];
	
	[self.tableView insertRowsAtIndexPaths:self.insertedIndexPaths
						  withRowAnimation:UITableViewRowAnimationTop];
	[self.tableView deleteRowsAtIndexPaths:self.deletedIndexPaths
						  withRowAnimation:UITableViewRowAnimationTop];
	[self.tableView reloadRowsAtIndexPaths:self.updatedIndexPaths
						  withRowAnimation:UITableViewRowAnimationNone];
	
	[self.tableView endUpdates];
	
	[self.insertedSections removeAllIndexes];
	[self.deletedSections removeAllIndexes];
	
	[self.insertedIndexPaths removeAllObjects];
	[self.deletedIndexPaths removeAllObjects];
	[self.updatedIndexPaths removeAllObjects];
}

- (NSIndexPath *)displayIndexPathForCoreDataIndexPath:(NSIndexPath *)indexPath {
	return indexPath;
}

- (NSIndexPath *)coreDataIndexPathForDisplayIndexPath:(NSIndexPath *)indexPath {
	return indexPath;
}

- (NSInteger)displaySectionForCoreDataSection:(NSInteger)section {
	return section;
}

- (NSInteger)coreDataSectionForDisplaySection:(NSInteger)section {
	return section;
}

@end
