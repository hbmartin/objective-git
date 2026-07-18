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
		NSError *error;
		GTCredential *cred = [GTCredential credentialWithUserName:@"null" publicKeyString:@"pub" privateKeyString:@"priv" passphrase:@"pass" error:&error];

		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});
});

describe(@"version and backends", ^{
	it(@"reports libgit2 1.9.4", ^{
		int major = 0, minor = 0, rev = 0;
		git_libgit2_version(&major, &minor, &rev);
		expect(@(major)).to(equal(@1));
		expect(@(minor)).to(equal(@9));
		expect(@(rev)).to(equal(@4));
	});

	it(@"uses the pthread threads backend", ^{
		expect(@(git_libgit2_feature_backend(GIT_FEATURE_THREADS))).to(equal(@"pthread"));
	});

	it(@"uses the SecureTransport HTTPS backend", ^{
		expect(@(git_libgit2_feature_backend(GIT_FEATURE_HTTPS))).to(equal(@"securetransport"));
	});

	it(@"uses the libssh2 SSH backend and not the exec/OpenSSH backend", ^{
		NSString *backend = @(git_libgit2_feature_backend(GIT_FEATURE_SSH));
		expect(backend).to(equal(@"libssh2"));
		expect(backend).notTo(equal(@"exec"));
	});
});

describe(@"server timeout", ^{
	it(@"can set and read the server timeout option", ^{
		int rc = git_libgit2_opts(GIT_OPT_SET_SERVER_TIMEOUT, (int)5000);
		expect(@(rc)).to(equal(@(GIT_OK)));

		int timeout = 0;
		rc = git_libgit2_opts(GIT_OPT_GET_SERVER_TIMEOUT, &timeout);
		expect(@(rc)).to(equal(@(GIT_OK)));
		expect(@(timeout)).to(equal(@5000));
	});
});

QuickSpecEnd
