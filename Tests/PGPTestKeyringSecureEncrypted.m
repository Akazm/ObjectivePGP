//
//  Copyright (c) Marcin Krzyżanowski. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY
//  INTERNATIONAL COPYRIGHT LAW. USAGE IS BOUND TO THE LICENSE AGREEMENT.
//  This notice may not be removed from this file.
//

#import <ObjectivePGP/ObjectivePGP.h>
#import "PGPMacros+Private.h"
#import "PGPTestUtils.h"
#import <XCTest/XCTest.h>

@interface ObjectivePGPTestKeyringSecureEncrypted : XCTestCase
@property (nonatomic) NSString *workingDirectory;
@property (nonatomic) ObjectivePGP *pgp;
@end

@implementation ObjectivePGPTestKeyringSecureEncrypted

- (void)setUp {
    [super setUp];
    self.pgp = [[ObjectivePGP alloc] init];
    NSString *newDir = [@"ObjectivePGPTests" stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSString *tmpDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:newDir];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    if (![[NSFileManager defaultManager] fileExistsAtPath:tmpDirectoryPath]) {
        XCTFail(@"couldn't create tmpDirectoryPath");
    }
    self.workingDirectory = tmpDirectoryPath;
}

- (void)importSecureKeyring {
    let keys = [PGPTestUtils readKeysFromFile:@"secring-test-encrypted.gpg"];
    [self.pgp.defaultKeyring importKeys:keys];
}

- (void)importPublicKeyring {
    let keys = [PGPTestUtils readKeysFromFile:@"pubring-test-encrypted.gpg"];
    [self.pgp.defaultKeyring importKeys:keys];
}

- (void)tearDown {
    [super tearDown];
    [[NSFileManager defaultManager] removeItemAtPath:self.workingDirectory error:nil];
    self.pgp = nil;
}

- (void)testLoadKeyring {
    [self importSecureKeyring];
    XCTAssert(self.pgp.defaultKeyring.keys.count == 1, @"Should load 1 key");
}

- (void)testUsers {
    [self importSecureKeyring];

    let key = self.pgp.defaultKeyring.keys.firstObject;
    XCTAssert(key.secretKey.users.count == 1, @"Invalid users count");
}

- (void)testPrimaryKey {
    [self importSecureKeyring];

    let key = self.pgp.defaultKeyring.keys.firstObject;
    XCTAssertTrue(key.isEncryptedWithPassword, @"Should be encrypted");
    XCTAssertEqualObjects([key.keyID longIdentifier], @"9528AAA17A9BC007", @"Invalid key identifier");
}

- (void)testKeyDecryption {
    [self importSecureKeyring];
    let key = self.pgp.defaultKeyring.keys.firstObject;

    XCTAssertTrue(key.isEncryptedWithPassword);

    NSError *decryptError = nil;
    let decryptedKey = [key decryptedWithPassphrase:@"1234" error:&decryptError];
    XCTAssertNotEqualObjects(key, decryptedKey);
    XCTAssertNotNil(decryptedKey, @"Decryption failed");
    XCTAssertNil(decryptError, @"Decryption failed");
}

- (void)testDataDecryption {
    [self importSecureKeyring];
    [self importPublicKeyring];

    let encKey = [self.pgp.defaultKeyring findKeyWithIdentifier:@"9528AAA17A9BC007"];
    // encrypt
    NSData *tmpdata = [@"this is test" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *encError;
    NSData *encData = [ObjectivePGP encrypt:tmpdata addSignature:NO usingKeys:@[encKey] passphraseForKey:nil error:&encError];
    XCTAssertNil(encError, @"Encryption failed");

    NSError *decError;
    NSData *decData = [ObjectivePGP decrypt:encData usingKeys:self.pgp.defaultKeyring.keys passphraseForKey:^NSString * _Nullable(PGPKey * _Nonnull key) { return @"1234"; } verifySignature:YES error:&decError];
    XCTAssertNotNil(decError, @"Decryption failed");
    XCTAssertNotNil(decData);
    XCTAssertEqualObjects(tmpdata, decData);
}

- (void)testEncryptedSignature {
    [self importSecureKeyring];
    BOOL status;

    // file to sign
    NSString *fileToSignPath = [self.workingDirectory stringByAppendingPathComponent:@"signed_file.bin"];
    status = [[@"12345678901234567890123456789" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:fileToSignPath atomically:YES];
    XCTAssertTrue(status);

    let keyToSign = [self.pgp.defaultKeyring findKeyWithIdentifier:@"9528AAA17A9BC007"];
    XCTAssertNotNil(keyToSign);

    // detached signature
    NSError *signatureError = nil;
    let data = [NSData dataWithContentsOfFile:fileToSignPath];
    let signatureData = [ObjectivePGP sign:data detached:YES usingKeys:@[keyToSign] passphraseForKey:^NSString * _Nullable(PGPKey *k) { return @"1234"; } error:&signatureError];
    XCTAssertNotNil(signatureData);
    XCTAssertNil(signatureError);

    NSString *signaturePath = [self.workingDirectory stringByAppendingPathComponent:@"signature.sig"];
    status = [signatureData writeToFile:signaturePath atomically:YES];
    XCTAssertTrue(status);
}

@end
