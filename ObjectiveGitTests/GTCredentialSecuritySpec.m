//
//  GTCredentialSecuritySpec.m
//  ObjectiveGitFramework
//
//  Regression coverage for the custom SSH credential disposal path. On libgit2
//  0.28.5 the custom-credential free path used strlen() and over-read a
//  non-NUL-terminated public key (an AddressSanitizer failure); libgit2 1.9.4
//  frees using the stored length and is safe. Run under ASan/UBSan in CI.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

#import "git2/credential.h"

QuickSpecBegin(GTCredentialSecuritySpec)

describe(@"custom SSH credential disposal", ^{
	it(@"safely disposes of non-NUL-terminated binary public-key data", ^{
		unsigned char publickey[32];
		for (NSUInteger i = 0; i < sizeof(publickey); i++) {
			publickey[i] = (unsigned char)(0xFF - i); // binary, no NUL terminator
		}

		git_credential *cred = NULL;
		int rc = git_credential_ssh_custom_new(&cred, "git", (const char *)publickey, sizeof(publickey), NULL, NULL);
		expect(@(rc)).to(equal(@(GIT_OK)));
		expect(@(cred != NULL)).to(beTruthy());

		// Disposal must zero/free exactly `publickey_len` bytes, never over-read.
		git_credential_free(cred);
	});

	it(@"safely disposes of an empty custom public key", ^{
		git_credential *cred = NULL;
		int rc = git_credential_ssh_custom_new(&cred, "git", NULL, 0, NULL, NULL);
		expect(@(rc)).to(equal(@(GIT_OK)));
		expect(@(cred != NULL)).to(beTruthy());

		git_credential_free(cred);
	});
});

QuickSpecEnd
