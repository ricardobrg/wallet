/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/asn1/asn1_object.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_object_identifier.dart';
import 'package:pointycastle/asn1/primitives/asn1_octet_string.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/signers/rsa_signer.dart';

import '../crypto_utils.dart' as utils;
import 'crypto_rsa_public_key.dart';

class CryptoRSAPrivateKey extends RSAPrivateKey {
  CryptoRSAPrivateKey(
      BigInt modulus, BigInt privateExponent, BigInt? p, BigInt? q)
      : super(modulus, privateExponent, p, q);

  static CryptoRSAPrivateKey decode(String encodedKey) {
    ASN1Parser topLevelParser = new ASN1Parser(base64.decode(encodedKey));
    ASN1Sequence topLevelSeq = topLevelParser.nextObject() as ASN1Sequence;

    ASN1Integer version = topLevelSeq.elements![0] as ASN1Integer;
    ASN1Sequence algorithmSeq = topLevelSeq.elements![1] as ASN1Sequence;
    ASN1OctetString privateKeyOctet =
        topLevelSeq.elements![2] as ASN1OctetString;

    ASN1Sequence publicKeySeq =
        ASN1Sequence.fromBytes(privateKeyOctet.octets as Uint8List);
    ASN1Integer privateKeyVersion = publicKeySeq.elements![0] as ASN1Integer;
    ASN1Integer modulus = publicKeySeq.elements![1] as ASN1Integer;
    ASN1Integer publicExponent = publicKeySeq.elements![2] as ASN1Integer;
    ASN1Integer privateExponent = publicKeySeq.elements![3] as ASN1Integer;
    ASN1Integer prime1 = publicKeySeq.elements![4] as ASN1Integer;
    ASN1Integer prime2 = publicKeySeq.elements![5] as ASN1Integer;
    ASN1Integer exponent1 = publicKeySeq.elements![6] as ASN1Integer;
    ASN1Integer exponent2 = publicKeySeq.elements![7] as ASN1Integer;
    ASN1Integer coefficient = publicKeySeq.elements![8] as ASN1Integer;

    return CryptoRSAPrivateKey(modulus.integer!, privateExponent.integer!,
        prime1.integer, prime2.integer);
  }

  CryptoRSAPublicKey get public =>
      CryptoRSAPublicKey(this.modulus!, this.publicExponent!);

  String encode() {
    ASN1Sequence sequence = ASN1Sequence();
    ASN1Integer version = ASN1Integer(BigInt.from(0));
    ASN1Sequence algorithm = ASN1Sequence();
    ASN1Object paramsAsn1Obj =
        ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithm
        .add(ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'));
    algorithm.add(paramsAsn1Obj);

    ASN1Sequence privateKeySequence = ASN1Sequence();
    ASN1Integer privateKeyVersion = ASN1Integer(BigInt.from(1));
    ASN1Integer modulus = ASN1Integer(this.modulus);
    ASN1Integer publicExponent = ASN1Integer(this.publicExponent);
    ASN1Integer privateExponent = ASN1Integer(this.privateExponent);
    ASN1Integer prime1 = ASN1Integer(this.p);
    ASN1Integer prime2 = ASN1Integer(this.q);
    ASN1Integer exponent1 =
        ASN1Integer(this.privateExponent! % (this.p! - BigInt.from(1)));
    ASN1Integer exponent2 =
        ASN1Integer(this.privateExponent! % (this.q! - BigInt.from(1)));
    ASN1Integer coefficient = ASN1Integer(this.q!.modInverse(this.p!));
    privateKeySequence.add(privateKeyVersion);
    privateKeySequence.add(modulus);
    privateKeySequence.add(publicExponent);
    privateKeySequence.add(privateExponent);
    privateKeySequence.add(prime1);
    privateKeySequence.add(prime2);
    privateKeySequence.add(exponent1);
    privateKeySequence.add(exponent2);
    privateKeySequence.add(coefficient);
    privateKeySequence.encode();
    ASN1OctetString privateKeyOctet = ASN1OctetString();
    privateKeyOctet.octets = privateKeySequence.encodedBytes;

    sequence.add(version);
    sequence.add(algorithm);
    sequence.add(privateKeyOctet);
    sequence.encode();
    return base64.encode(sequence.encodedBytes!);
  }

  Uint8List decrypt(Uint8List ciphertext) {
    final decryptor = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(this));
    return utils.processInBlocks(decryptor, ciphertext);
  }

  Uint8List sign(Uint8List message) {
    RSASigner signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(this));
    RSASignature signature = signer.generateSignature(message);
    return signature.bytes;
  }
}
