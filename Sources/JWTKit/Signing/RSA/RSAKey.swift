import CJWTKitCrypto
import struct Foundation.Data

public final class RSAKey: OpenSSLKey {
    public static func `public`<Data>(pem data: Data) throws -> RSAKey
        where Data: DataProtocol
    {
        let pkey = try self.load(pem: data) { bio in
            PEM_read_bio_PUBKEY(convert(bio), nil, nil, nil)
        }
        defer { EVP_PKEY_free(pkey) }

        guard let c = EVP_PKEY_get1_RSA(pkey) else {
            throw JWTError.signingAlgorithmFailure(RSAError.keyInitializationFailure)
        }
        return self.init(convert(c), .public)
    }

    public static func `private`<Data>(pem data: Data) throws -> RSAKey
        where Data: DataProtocol
    {
        let pkey = try self.load(pem: data) { bio in
            PEM_read_bio_PrivateKey(convert(bio), nil, nil, nil)
        }
        defer { EVP_PKEY_free(pkey) }

        guard let c = EVP_PKEY_get1_RSA(pkey) else {
            throw JWTError.signingAlgorithmFailure(RSAError.keyInitializationFailure)
        }
        return self.init(convert(c), .private)
    }

    public convenience init?(
        modulus: String,
        exponent: String,
        privateExponent: String? = nil
    ) {
        func decode(_ string: String) -> [UInt8] {
            return [UInt8](string.utf8).base64URLDecodedBytes()
        }
        let n = decode(modulus)
        let e = decode(exponent)
        let d = privateExponent.flatMap { decode($0) }

        guard let rsa = RSA_new() else {
            return nil
        }

        jwtkit_RSA_set0_key(
            rsa,
            BN_bin2bn(n, numericCast(n.count), nil),
            BN_bin2bn(e, numericCast(e.count), nil),
            d.flatMap { BN_bin2bn($0, numericCast($0.count), nil) }
        )
        self.init(convert(rsa), d == nil ? .public : .private)
    }

    enum KeyType {
        case `public`, `private`
    }

    let type: KeyType
    let c: OpaquePointer

    init(_ c: OpaquePointer, _ type: KeyType) {
        self.type = type
        self.c = c
    }

    deinit {
        RSA_free(convert(self.c))
    }
}