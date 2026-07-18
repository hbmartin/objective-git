//
//  GTCredentialSpec.m
//  ObjectiveGitFramework
//
//  Characterizes GTCredential creation and GTCredentialProvider behavior across
//  the libgit2 upgrade. These exercise ObjectiveGit's stable public API only,
//  so they hold on both the pre- and post-upgrade libgit2.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

#import "GTCredential+Private.h"
#import "git2/errors.h"

QuickSpecBegin(GTCredentialSpec)

describe(@"username / password credentials", ^{
	it(@"creates a username/password credential", ^{
		NSError *error = nil;
		GTCredential *cred = [GTCredential credentialWithUserName:@"user" password:@"secret" error:&error];
		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});
});

describe(@"key-file credentials", ^{
	it(@"creates a key-file credential (paths need not exist at creation time)", ^{
		NSURL *publicKey = [NSURL fileURLWithPath:@"/tmp/objective-git-nonexistent.pub"];
		NSURL *privateKey = [NSURL fileURLWithPath:@"/tmp/objective-git-nonexistent"];

		NSError *error = nil;
		GTCredential *cred = [GTCredential credentialWithUserName:@"git" publicKeyURL:publicKey privateKeyURL:privateKey passphrase:@"" error:&error];
		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});
});

describe(@"in-memory SSH credentials", ^{
	it(@"creates an in-memory SSH credential", ^{
		NSError *error = nil;
		GTCredential *cred = [GTCredential credentialWithUserName:@"git" publicKeyString:@"ssh-rsa AAAA" privateKeyString:@"-----BEGIN OPENSSH PRIVATE KEY-----" passphrase:@"" error:&error];
		expect(cred).notTo(beNil());
		expect(error).to(beNil());
	});
});

describe(@"GTCredentialProvider", ^{
	it(@"returns the credential produced by its block", ^{
		NSError *error = nil;
		GTCredential *expected = [GTCredential credentialWithUserName:@"user" password:@"secret" error:&error];
		expect(expected).notTo(beNil());

		GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential *(GTCredentialType type, NSString *URL, NSString *userName) {
			return expected;
		}];

		GTCredential *provided = [provider credentialForType:GTCredentialTypeUserPassPlaintext URL:@"https://example.com" userName:@"user"];
		expect(provided).to(beIdenticalTo(expected));
	});

	it(@"passes nil URL and userName through to its block", ^{
		__block BOOL called = NO;
		GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential *(GTCredentialType type, NSString *URL, NSString *userName) {
			called = YES;
			expect(URL).to(beNil());
			expect(userName).to(beNil());
			return nil;
		}];

		GTCredential *provided = [provider credentialForType:GTCredentialTypeSSHKey URL:nil userName:nil];
		expect(@(called)).to(beTruthy());
		expect(provided).to(beNil());
	});

	it(@"declines by returning nil from its block", ^{
		GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential *(GTCredentialType type, NSString *URL, NSString *userName) {
			return nil;
		}];

		GTCredential *provided = [provider credentialForType:GTCredentialTypeUserPassPlaintext URL:@"https://example.com" userName:@"user"];
		expect(provided).to(beNil());
	});
});

describe(@"GTCredentialAcquireCallback", ^{
	it(@"rejects a NULL credential output pointer", ^{
		GTCredentialAcquireCallbackInfo info = { .credProvider = nil };

		int result = GTCredentialAcquireCallback(NULL, NULL, NULL, 0, &info);

		expect(@(result)).to(equal(@(GIT_ERROR)));
	});

	it(@"clears the credential output before rejecting a NULL payload", ^{
		git_credential *credential = (git_credential *)0x1;

		int result = GTCredentialAcquireCallback(&credential, NULL, NULL, 0, NULL);

		expect(@(result)).to(equal(@(GIT_ERROR)));
		expect([NSValue valueWithPointer:credential]).to(equal([NSValue valueWithPointer:NULL]));
	});
});

QuickSpecEnd
