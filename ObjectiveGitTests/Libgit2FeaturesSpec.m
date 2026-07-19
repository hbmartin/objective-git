//
//  Libgit2FeaturesSpec.m
//  ObjectiveGitFramework
//
//  Created by Ben Chatelain on 7/6/15.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"
#import "../ObjectiveGit/GTCredential+Private.h"

QuickSpecBegin(Libgit2FeaturesSpec)

describe(@"libgit", ^{

	__block git_feature_t git_features = 0;

	beforeEach(^{
		git_features = git_libgit2_features();
	});

	it(@"should be built with THREADS enabled", ^{
		expect(@(git_features & GIT_FEATURE_THREADS)).to(beTruthy());
	});

	it(@"should be built with HTTPS enabled", ^{
		expect(@(git_features & GIT_FEATURE_HTTPS)).to(beTruthy());
	});

	it(@"should be built with SSH enabled", ^{
		expect(@(git_features & GIT_FEATURE_SSH)).to(beTruthy());
	});

	it(@"should have ssh memory credentials", ^{
		NSError *error = nil;
		GTCredential *cred = [GTCredential credentialWithUserName:@"null" publicKeyString:@"pub" privateKeyString:@"priv" passphrase:@"pass" error:&error];

		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});

	it(@"should create username and password credentials", ^{
		NSError *error = nil;
		GTCredential *cred = [GTCredential credentialWithUserName:@"octocat" password:@"secret" error:&error];

		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});

	it(@"should create SSH key file credentials without a public key file", ^{
		NSError *error = nil;
		NSURL *privateKeyURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"objective-git-private-key"]];
		GTCredential *cred = [GTCredential credentialWithUserName:@"git" publicKeyURL:nil privateKeyURL:privateKeyURL passphrase:nil error:&error];

		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});

	it(@"should pass authentication request details to the credential provider", ^{
		__block GTCredentialType requestedType = 0;
		__block NSString *requestedURL = nil;
		__block NSString *requestedUserName = nil;
		GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential *(GTCredentialType type, NSString *URL, NSString *userName) {
			requestedType = type;
			requestedURL = URL;
			requestedUserName = userName;
			return [GTCredential credentialWithUserName:@"git" password:@"secret" error:NULL];
		}];
		GTCredentialAcquireCallbackInfo info = { .credProvider = provider };
		git_cred *credential = NULL;

		int result = GTCredentialAcquireCallback(&credential, "ssh://example.com/repository.git", "octocat", GIT_CREDTYPE_USERPASS_PLAINTEXT | GIT_CREDTYPE_SSH_KEY, &info);

		expect(@(result)).to(equal(@(GIT_OK)));
		expect([NSValue valueWithPointer:credential]).notTo(equal([NSValue valueWithPointer:NULL]));
		expect(@(requestedType)).to(equal(@(GIT_CREDTYPE_USERPASS_PLAINTEXT | GIT_CREDTYPE_SSH_KEY)));
		expect(requestedURL).to(equal(@"ssh://example.com/repository.git"));
		expect(requestedUserName).to(equal(@"octocat"));
		git_cred_free(credential);
	});

	it(@"should map missing authentication request strings to safe Objective-C values", ^{
		__block NSString *requestedURL = nil;
		__block NSString *requestedUserName = @"unexpected";
		GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential *(GTCredentialType type, NSString *URL, NSString *userName) {
			requestedURL = URL;
			requestedUserName = userName;
			return nil;
		}];
		GTCredentialAcquireCallbackInfo info = { .credProvider = provider };
		git_cred *credential = NULL;

		int result = GTCredentialAcquireCallback(&credential, NULL, NULL, GIT_CREDTYPE_SSH_KEY, &info);

		expect(@(result)).to(equal(@(GIT_ERROR)));
		expect(requestedURL).to(equal(@""));
		expect(requestedUserName).to(beNil());
	});

	it(@"should fail authentication when no provider is configured", ^{
		GTCredentialAcquireCallbackInfo info = { .credProvider = nil };
		git_cred *credential = NULL;

		int result = GTCredentialAcquireCallback(&credential, "ssh://example.com/repository.git", "git", GIT_CREDTYPE_SSH_KEY, &info);

		expect(@(result)).to(equal(@(GIT_ERROR)));
		expect([NSValue valueWithPointer:credential]).to(equal([NSValue valueWithPointer:NULL]));
	});

	it(@"should fail authentication when the provider declines the request", ^{
		GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential *(GTCredentialType type, NSString *URL, NSString *userName) {
			return nil;
		}];
		GTCredentialAcquireCallbackInfo info = { .credProvider = provider };
		git_cred *credential = NULL;

		int result = GTCredentialAcquireCallback(&credential, "ssh://example.com/repository.git", "git", GIT_CREDTYPE_SSH_KEY, &info);

		expect(@(result)).to(equal(@(GIT_ERROR)));
		expect([NSValue valueWithPointer:credential]).to(equal([NSValue valueWithPointer:NULL]));
	});
});

QuickSpecEnd
