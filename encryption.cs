using Godot;
using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using SerbleNotes;

public partial class encryption : Node {
	
	public string Encrypt(string plainText, string password) {
		try {
			GD.Print("I exist (C# Code)");
			byte[] iv = GetBytes(12); // fill array of 16 elements with cryptographically strong sequences of random values.

			byte[] passwordBytes = Encoding.UTF8.GetBytes(password);
			byte[] hashedPasswordBytes = SHA256.Create().ComputeHash(passwordBytes);
			
			byte[] encrypted = EncryptStringToBytes_AesGcm(plainText, hashedPasswordBytes, iv);
			string result = IvToHex(iv) + Convert.ToBase64String(encrypted);
			result.Length.WriteLine("Encrypt result length: ");
			return result;
		}
		catch (Exception e) {
			GD.PrintErr("Error: " + e);
			throw;
		}
	}

	public string Decrypt(string cipherTextPlusIv, string password) {
		try {
			cipherTextPlusIv.Length.WriteLine("Decrypt cipherTextPlusIv length: ");
			string[] parts = { cipherTextPlusIv[..24], cipherTextPlusIv[24..] };
			byte[] iv = HexToIv(parts[0]);
			iv.Length.WriteLine("Decrypt iv length: ");
			byte[] cipherText = Convert.FromBase64String(parts[1]);
			cipherText.WriteLine("Decrypt cipherText: ");
			cipherText.Length.WriteLine("Decrypt cipherText length: ");
		
			byte[] passwordBytes = Encoding.UTF8.GetBytes(password);
			byte[] hashedPasswordBytes = SHA256.Create().ComputeHash(passwordBytes);

			return DecryptStringFromBytes_AesGcm(cipherText, hashedPasswordBytes, iv);
			//return Encoding.UTF8.GetString(
			//	Convert.FromBase64String(DecryptStringFromBytes_AesGcm(cipherText, hashedPasswordBytes, iv)));
		}
		catch (Exception e) {
			GD.PrintErr("Error: " + e);
			throw;
		}
	}
	
	public static string IvToHex(byte[] iv) {
		StringBuilder sb = new StringBuilder();
		foreach (byte b in iv) {
			sb.Append(b.ToString("x2"));
		}
		return sb.ToString();
	}

	public static byte[] HexToIv(string hexIv) {
		byte[] iv = new byte[hexIv.Length / 2];
		for (int i = 0; i < iv.Length; i++) {
			try {
				iv[i] = Convert.ToByte(hexIv.Substring(i * 2, 2), 16);
			}
			catch (Exception) {
				GD.PrintErr("Error in byte: " + i + " of " + iv.Length + " (" + hexIv.Substring(i * 2, 2) + ")");
				GD.PrintErr("Hex: " + hexIv);
				throw;
			}
		}
		return iv;
	}
	
	public static byte[] GetBytes(int length) {
		Random random = new();
		byte[] buffer = new byte[length];
		
		random.NextBytes(buffer);
		return buffer;
	}

	private static byte[] EncryptStringToBytes_Aes(string plainText, byte[] Key, byte[] IV) {
		using Aes aesAlg = Aes.Create();
		aesAlg.Key = Key;
		aesAlg.IV = IV;

		ICryptoTransform encryptor = aesAlg.CreateEncryptor(aesAlg.Key, aesAlg.IV);
		using MemoryStream msEncrypt = new MemoryStream();
		using (CryptoStream csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write)) {
			using (StreamWriter swEncrypt = new StreamWriter(csEncrypt)) {
				swEncrypt.Write(plainText);
			}
			return msEncrypt.ToArray();
		}
	}

	private static string DecryptStringFromBytes_Aes(byte[] cipherText, byte[] Key, byte[] IV) {
		using Aes aesAlg = Aes.Create();
		aesAlg.Key = Key;
		aesAlg.IV = IV;

		ICryptoTransform decryptor = aesAlg.CreateDecryptor(aesAlg.Key, aesAlg.IV);
		using MemoryStream msDecrypt = new MemoryStream(cipherText);
		using CryptoStream csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read);
		using StreamReader srDecrypt = new StreamReader(csDecrypt);
		return srDecrypt.ReadToEnd();
	}
	
	private static byte[] EncryptStringToBytes_AesGcm(string plainText, byte[] Key, byte[] nonce) {
		using AesGcm aesGcm = new AesGcm(Key);
		byte[] plainTextBytes = Encoding.UTF8.GetBytes(plainText).WriteLine("Encrypt plainTextBytes: ");
		byte[] cipherTextBytes = new byte[plainTextBytes.Length];
		byte[] tag = new byte[16];

		aesGcm.Encrypt(nonce, plainTextBytes, cipherTextBytes, tag);
		tag.WriteLine("Encrypt tag: ");

		byte[] result = new byte[cipherTextBytes.Length + tag.Length];
		//Buffer.BlockCopy(nonce.WriteLine("Encryot nonce: "),                        0, result, 0,                                              nonce.Length);
		Buffer.BlockCopy(cipherTextBytes,              0, result, 0,                                   cipherTextBytes.Length);
		Buffer.BlockCopy(tag,                          0, result, cipherTextBytes.Length,           tag.Length);

		result.Length.WriteLine("Encrypt result length: ");
		return result;
	}

	private static string DecryptStringFromBytes_AesGcm(byte[] cipherTextWithNonceAndTag, byte[] Key, byte[] nonce) {
		cipherTextWithNonceAndTag.Length.WriteLine("Decrypt inp length: ");
		
		//byte[] nonce = cipherTextWithNonceAndTag.Take(12).ToArray().WriteLine("Decrypt nonce: ");
		byte[] cipherText = cipherTextWithNonceAndTag.Take(cipherTextWithNonceAndTag.Length - 16).ToArray();
		byte[] tag = cipherTextWithNonceAndTag.Skip(cipherText.Length).ToArray().WriteLine("Decrypt tag: ");

		using AesGcm aesGcm = new AesGcm(Key);
		byte[] decryptedData = new byte[cipherText.Length];
		aesGcm.Decrypt(nonce, cipherText, tag, decryptedData);

		return Encoding.UTF8.GetString(decryptedData);
	}
	
}
