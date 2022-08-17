//
//  CryptographyInUseManager.swift
//  cryptography-in-use
//
//  Created by Mojtaba Mirzadeh on 6/14/1400 AP.
//

import Foundation
import CryptoKit

public class CryptographyInUseManager {
    
    public init(){}
    
    private var _sampleData : Data!
    private var _x509Certificate : X509Certificate!
    private var _signedData : SignedData!
    private var _signerInfo : SignerInfo!
    private var _keyExchange : KeyExchange!
    
    //use for Doc Sign
    public func makeCmsSignedAttributes(certificate: String, sampleDocument: String) -> Data {
        
        // Convert the sample text data to array of bytes
        self._sampleData = sampleDocument.data(using:.utf8)!
        
        // Load Certificate
        self._x509Certificate = try! loadPemCertificate(loadCertificate: certificate)
        
        // Define a Signed data
        self._signedData = SignedData(version: CmsVersion.v3, explicit: true)
        
        // Define the Digest Algorithms included in Signed Data
        self._signedData.addDigestAlgorithm(digestAlgorithmId:DigestAlgorithmId.sha256)
        
        // Define Encapsulated Content Info of Signed Data
        self._signedData.setEncapsulatedContentInfo(content: self._sampleData)
        
        // Set certificate
        self._signedData.addCertificate(x509Certificate: self._x509Certificate)
        
        // Define Signer Infos included in Signed Data
        self._signerInfo = SignerInfo(version: CmsVersion.v1, x509Certificate: self._x509Certificate)
        self._signerInfo.digestAlgorithm = DigestAlgorithmId.sha256
        self._signerInfo.signatureAlgorithm = SignatureAlgorithmId.sha256_ecdsa
        if #available(iOS 13.0, *) {
            let hash = SHA256.hash(data: self._sampleData).compactMap{ String(format: "%02x", $0) }.joined()
            self._signerInfo.initSignedAttributes(signingTime: Date(), //***Set Date()***
                                                  digestAlgorithmId: DigestAlgorithmId.sha256,
                                                  signatureAlgorithmId: SignatureAlgorithmId.sha256_ecdsa,
                                                  digestedData: hash)
        } else {
            // Fallback on earlier versions
        }
        
        // Signed Attributes should be set as the input of Digital Signature process
        print("Signed Attributes For Sign : ", self._signerInfo.signedAttributes.serialize().hexString())
        
        return self._signerInfo.signedAttributes.serialize()
    }
    
    //use for PDF Sign
    public func makeCmsSignedAttributesWithData(certificate: String, sampleDocument: Data) -> Data {
        
        // Convert the sample text data to array of bytes
        self._sampleData = sampleDocument//sampleDocument.data(using:.utf8)!
        
        // Load Certificate
        self._x509Certificate = try! loadPemCertificate(loadCertificate: certificate)
        
        // Define a Signed data
        self._signedData = SignedData(version: CmsVersion.v3, explicit: true)
        
        // Define the Digest Algorithms included in Signed Data
        self._signedData.addDigestAlgorithm(digestAlgorithmId:DigestAlgorithmId.sha256)
        
        // Define Encapsulated Content Info of Signed Data
        self._signedData.setEncapsulatedContentInfo(content: self._sampleData)
        
        // Set certificate
        self._signedData.addCertificate(x509Certificate: self._x509Certificate)
        
        // Define Signer Infos included in Signed Data
        self._signerInfo = SignerInfo(version: CmsVersion.v1, x509Certificate: self._x509Certificate)
        self._signerInfo.digestAlgorithm = DigestAlgorithmId.sha256
        self._signerInfo.signatureAlgorithm = SignatureAlgorithmId.sha256_ecdsa
        if #available(iOS 13.0, *) {
            //let hash = SHA256.hash(data: self._sampleData).compactMap{ String(format: "%02x", $0) }.joined()
            let _sampleDataToString = self._sampleData.compactMap{ String(format: "%02x", $0) }.joined()
            
            self._signerInfo.initSignedAttributes(signingTime: Date(), //***Set Date()***
                                                  digestAlgorithmId: DigestAlgorithmId.sha256,
                                                  signatureAlgorithmId: SignatureAlgorithmId.sha256_ecdsa,
                                                  digestedData: _sampleDataToString)
        } else {
            // Fallback on earlier versions
        }
        
        // Signed Attributes should be set as the input of Digital Signature process
        print("Signed Attributes For Sign : ", self._signerInfo.signedAttributes.serialize().hexString())
        
        return self._signerInfo.signedAttributes.serialize()
    }
    
    public func makeCmsSignedData(signature: String) -> String {
        
        // Signature of plain data
        let signatureData = Data(base64Encoded: signature)
        self._signerInfo.signature = signatureData!
        
        self._signedData.addSignerInfo(signerInfo: self._signerInfo)
        
        let cms = ContentInfo(contentType: Oid.SignedData)
        cms.content = (self._signedData)
        
        let encodedData = try! cms.asn1encode(tag: nil).serialize()
        print("CMS Data Base64 : ", encodedData.base64EncodedString())
        
        return encodedData.base64EncodedString()
    }
    
    func loadPemCertificate(loadCertificate: String) throws -> X509Certificate {
        let certificateData = loadCertificate.data(using: .utf8)!
        return try X509Certificate(data: certificateData)
    }
    
    // MARK: - KeyExchange
    public func makePublicKeyForServer(clientPrivatekey: SecKey)-> String{
        let clientPublicKey = SecKeyCopyPublicKey(clientPrivatekey)
        let publicKeyData = SecKeyCopyExternalRepresentation(clientPublicKey!, nil)! as Data
        let algorithmIdentifier = SignatureAlgorithmIdentifier(algorithm : OID.ecPublicKey.rawValue, parameter: OID.prime256v1.rawValue)
        let subjectPublicKey = BitString(data: publicKeyData)
        let clientPublicKeyInfo = SubjectPublicKeyInfo(algorithm: algorithmIdentifier, subjectPublicKey: subjectPublicKey)
        print("Client Public Key : ", clientPublicKeyInfo.pem())
        return clientPublicKeyInfo.pem()
    }
    
    public func makeAes256SharedSecretKey(serverPublicKeyPem: String, clientPrivatekey: SecKey)-> String{
        let serverPublicKeyInfo = SubjectPublicKeyInfo.from(pem: serverPublicKeyPem)!
        let serverPublicKeyData = serverPublicKeyInfo.subjectPublicKey!.binaryData
        _keyExchange = KeyExchange(serverPublicKeyData: serverPublicKeyData, clientPrivateKey: clientPrivatekey)
        let sharedSecretKey : Data = self._keyExchange.deriveAes256SharedSecretKey()
        print("shared secret key: ", sharedSecretKey.hexString())
        return sharedSecretKey.hexString()
    }
}


