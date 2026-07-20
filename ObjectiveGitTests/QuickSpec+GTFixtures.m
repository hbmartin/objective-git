//
//  QuickSpec+GTFixtures.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 3/22/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "QuickSpec+GTFixtures.h"

@import ObjectiveC;
@import ObjectiveGit;
@import ZipArchive;

static const NSInteger FixturesErrorUnzipFailed = 666;

static NSString * const FixturesErrorDomain = @"com.objectivegit.Fixtures";

@interface QuickSpec (Fixtures)

@property (class, nonatomic, readonly, copy) NSString *repositoryFixturesPath;
@property (class, nonatomic, copy) NSString *tempDirectoryPath;

+ (BOOL)setUpTempDirectoryPath;
+ (BOOL)setUpRepositoryFixtureIfNeeded:(NSString *)repositoryName;
+ (BOOL)removeItemIfExistsAtPath:(NSString *)path error:(NSError **)error;

@end

@implementation QuickSpec (Fixtures)

#pragma mark Properties

+ (NSString *)tempDirectoryPath {
	NSString *path = objc_getAssociatedObject(self, _cmd);
	if (path != nil) return path;

	if (![self setUpTempDirectoryPath]) return nil;
	return objc_getAssociatedObject(self, _cmd);
}

+ (void)setTempDirectoryPath:(NSString *)path {
	objc_setAssociatedObject(self, @selector(tempDirectoryPath), path, OBJC_ASSOCIATION_COPY);
}

+ (NSURL *)tempDirectoryFileURL {
	NSString *path = self.tempDirectoryPath;
	if (path == nil) return nil;

	return [NSURL fileURLWithPath:path isDirectory:YES];
}

+ (NSString *)repositoryFixturesPath {
	NSString *path = self.tempDirectoryPath;
	if (path == nil) return nil;

	return [path stringByAppendingPathComponent:@"repositories"];
}

#pragma mark Setup/Teardown

- (void)tearDown {
	[super tearDown];

	[self.class cleanUp];
}

+ (void)cleanUp {
	NSString *path = objc_getAssociatedObject(self, @selector(tempDirectoryPath));
	if (path == nil) return;

	NSError *error = nil;
	BOOL success = [NSFileManager.defaultManager removeItemAtPath:path error:&error];
	if (!success) XCTFail(@"Couldn't remove the temp fixtures directory at %@: %@", path, error);

	self.tempDirectoryPath = nil;
}

#pragma mark Fixtures

+ (NSString *)rootTempDirectory {
	return [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.libgit2.objectivegit"];
}

+ (BOOL)setUpTempDirectoryPath {
	NSString *path = [self.rootTempDirectory stringByAppendingPathComponent:NSProcessInfo.processInfo.globallyUniqueString];

	NSError *error = nil;
	BOOL success = [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
	if (!success) {
		XCTFail(@"Couldn't create the temp fixtures directory at %@: %@", path, error);
		return NO;
	}

	self.tempDirectoryPath = path;
	return YES;
}

+ (BOOL)setUpRepositoryFixtureIfNeeded:(NSString *)repositoryName {
	NSString *repositoryFixturesPath = self.repositoryFixturesPath;
	if (repositoryFixturesPath == nil) return NO;

	NSString *path = [repositoryFixturesPath stringByAppendingPathComponent:repositoryName];

	BOOL isDirectory = NO;
	if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) return YES;

	NSError *error = nil;
	BOOL success = [NSFileManager.defaultManager createDirectoryAtPath:repositoryFixturesPath withIntermediateDirectories:YES attributes:nil error:&error];
	if (!success) {
		XCTFail(@"Couldn't create the repository fixtures directory at %@: %@", repositoryFixturesPath, error);
		return NO;
	}

	NSString *zippedRepositoriesPath = [[NSBundle bundleForClass:self] pathForResource:@"fixtures" ofType:@"zip"];
	if (zippedRepositoriesPath == nil) {
		XCTFail(@"Couldn't find fixtures.zip in %@", [NSBundle bundleForClass:self]);
		return NO;
	}

	NSString *cleanRepositoryPath = [self.rootTempDirectory stringByAppendingPathComponent:@"clean_repository"];
	if (![NSFileManager.defaultManager fileExistsAtPath:cleanRepositoryPath isDirectory:nil]) {
		// Unzip into a staging directory and only move it into place on
		// success, so an aborted extraction can't be mistaken for a valid
		// cache by every later run.
		NSString *stagingPath = [cleanRepositoryPath stringByAppendingPathExtension:@"staging"];
		error = nil;
		if (![self removeItemIfExistsAtPath:stagingPath error:&error]) {
			XCTFail(@"Couldn't remove the stale fixture staging directory at %@: %@", stagingPath, error);
			return NO;
		}

		error = nil;
		success = [self unzipFromArchiveAtPath:zippedRepositoriesPath intoDirectory:stagingPath error:&error];
		if (!success) {
			NSError *unzipError = error;
			NSError *cleanupError = nil;
			BOOL cleanupSuccess = [self removeItemIfExistsAtPath:stagingPath error:&cleanupError];
			if (cleanupSuccess) {
				XCTFail(@"Couldn't unzip fixture \"%@\" from %@ to %@: %@", repositoryName, zippedRepositoriesPath, stagingPath, unzipError);
			} else {
				XCTFail(@"Couldn't unzip fixture \"%@\" from %@ to %@: %@; staging cleanup also failed: %@", repositoryName, zippedRepositoriesPath, stagingPath, unzipError, cleanupError);
			}
			return NO;
		}

		error = nil;
		success = [NSFileManager.defaultManager moveItemAtPath:stagingPath toPath:cleanRepositoryPath error:&error];
		if (!success) {
			NSError *moveError = error;
			NSError *cleanupError = nil;
			BOOL cleanupSuccess = [self removeItemIfExistsAtPath:stagingPath error:&cleanupError];
			if (cleanupSuccess) {
				XCTFail(@"Couldn't move extracted fixtures from %@ to %@: %@", stagingPath, cleanRepositoryPath, moveError);
			} else {
				XCTFail(@"Couldn't move extracted fixtures from %@ to %@: %@; staging cleanup also failed: %@", stagingPath, cleanRepositoryPath, moveError, cleanupError);
			}
			return NO;
		}
	}

	success = [[NSFileManager defaultManager] copyItemAtPath:[cleanRepositoryPath stringByAppendingPathComponent:repositoryName] toPath:path error:&error];
	if (!success) {
		XCTFail(@"Couldn't copy fixture \"%@\" from %@ to %@: %@", repositoryName, cleanRepositoryPath, path, error);
		return NO;
	}

	return YES;
}

+ (NSString *)pathForFixtureRepositoryNamed:(NSString *)repositoryName {
	if (![self setUpRepositoryFixtureIfNeeded:repositoryName]) return nil;

	return [self.repositoryFixturesPath stringByAppendingPathComponent:repositoryName];
}

+ (BOOL)removeItemIfExistsAtPath:(NSString *)path error:(NSError **)error {
	if (path == nil) return YES;

	NSFileManager *fileManager = NSFileManager.defaultManager;
	NSError *localError = nil;
	if ([fileManager removeItemAtPath:path error:&localError]) return YES;

	if ([localError.domain isEqualToString:NSCocoaErrorDomain] && localError.code == NSFileNoSuchFileError) return YES;

	if (error != NULL) *error = localError;
	return NO;
}

+ (BOOL)unzipFromArchiveAtPath:(NSString *)zipPath intoDirectory:(NSString *)destinationPath error:(NSError **)error {
	BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:destinationPath overwrite:YES password:nil error:error];

	if (!success) {
		NSLog(@"Unzip failed");
		return NO;
	}

	return YES;
}

#pragma mark API

+ (GTRepository *)fixtureRepositoryNamed:(NSString *)name {
	NSString *path = [self pathForFixtureRepositoryNamed:name];
	if (path == nil) return nil;

	NSURL *url = [NSURL fileURLWithPath:path];
	NSError *error = nil;
	GTRepository *repository = [[GTRepository alloc] initWithURL:url error:&error];
	if (repository == nil) XCTFail(@"Couldn't create a repository for %@: %@", name, error);

	return repository;
}

+ (GTRepository *)testAppFixtureRepository {
	return [self fixtureRepositoryNamed:@"Test_App"];
}

+ (GTRepository *)testAppForkFixtureRepository {
	return [self fixtureRepositoryNamed:@"Test_App_fork"];
}

+ (GTRepository *)testUnicodeFixtureRepository {
	return [self fixtureRepositoryNamed:@"unicode-files-repo"];
}

+ (GTRepository *)bareFixtureRepository {
	return [self fixtureRepositoryNamed:@"testrepo.git"];
}

+ (GTRepository *)submoduleFixtureRepository {
	return [self fixtureRepositoryNamed:@"repo-with-submodule"];
}

+ (GTRepository *)conflictedFixtureRepository {
	return [self fixtureRepositoryNamed:@"conflicted-repo"];
}

+ (GTRepository *)blankFixtureRepository {
	NSURL *tempDirectoryURL = self.tempDirectoryFileURL;
	if (tempDirectoryURL == nil) return nil;

	NSURL *repoURL = [tempDirectoryURL URLByAppendingPathComponent:@"blank-repo"];
	NSError *error = nil;
	GTRepository *repository = [GTRepository initializeEmptyRepositoryAtFileURL:repoURL options:nil error:&error];
	if (repository == nil) XCTFail(@"Couldn't create a blank repository: %@", error);

	return repository;
}

+ (GTRepository *)blankBareFixtureRepository {
	NSURL *tempDirectoryURL = self.tempDirectoryFileURL;
	if (tempDirectoryURL == nil) return nil;

	NSURL *repoURL = [tempDirectoryURL URLByAppendingPathComponent:@"blank-repo.git"];
	NSDictionary *options = @{
		GTRepositoryInitOptionsFlags: @(GTRepositoryInitBare | GTRepositoryInitCreatingRepositoryDirectory)
	};

	NSError *error = nil;
	GTRepository *repository = [GTRepository initializeEmptyRepositoryAtFileURL:repoURL options:options error:&error];
	if (repository == nil) XCTFail(@"Couldn't create a blank repository: %@", error);

	return repository;
}

#pragma mark Properties

+ (NSBundle *)mainTestBundle {
	return [NSBundle bundleForClass:self];
}

@end
