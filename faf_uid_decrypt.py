from Crypto.PublicKey import RSA
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
from Crypto.Cipher import PKCS1_v1_5
import base64
import json

# Decrypt the RSA-encrypted AES key using PKCS1v15
def decrypt_aes_key_v15(encrypted_aes_key_b64, private_key):
    encrypted_aes_key = base64.b64decode(encrypted_aes_key_b64)
    cipher_rsa = PKCS1_v1_5.new(private_key)
    aes_key = cipher_rsa.decrypt(encrypted_aes_key, None)
    return aes_key

# Decrypt the JSON string using AES
def decrypt_json_string(aes_key, iv_b64, encrypted_json_b64):
    iv = base64.b64decode(iv_b64)
    encrypted_json = base64.b64decode(encrypted_json_b64)
    cipher_aes = AES.new(aes_key, AES.MODE_CBC, iv)
    decrypted_json = unpad(cipher_aes.decrypt(encrypted_json), AES.block_size)
    return decrypted_json.decode('utf-8')

# Main function to decrypt uid string
def decrypt_uid(encrypted_data: str, rsa_private_key: str):

    encrypted_data = base64.b64decode(encrypted_data)

    # Extract the padding size, IV, encrypted JSON, and encrypted AES key
    padding_size = encrypted_data[0]
    iv_b64 = encrypted_data[1:25]
    encrypted_json_b64 = encrypted_data[25: -344]
    encrypted_aes_key_b64 = encrypted_data[-344:]

    # Load the private RSA key
    private_key = RSA.import_key(rsa_private_key)

    # Step 1: Decrypt AES key using RSA (with PKCS1v15)
    aes_key = decrypt_aes_key_v15(encrypted_aes_key_b64, private_key)

    # Step 2: Decrypt the JSON string using AES
    json_string = decrypt_json_string(aes_key, iv_b64, encrypted_json_b64)
    json_string = json_string[1:]

    # Step 3: Parse the JSON string
    try:
        json_data = json.loads(json_string)
        return json_data
    except json.JSONDecodeError:
        print("Failed to decode JSON")
        return None

# Example usage
if __name__ == '__main__':
    uid_file = 'uid.txt'
    rsa_private_key_file = 'faf_priv.pem'

    with open(uid_file, 'r') as f:
        encrypted_data = f.read()

    with open(rsa_private_key_file, 'r') as f:
        rsa_private_key = f.read()

    decrypted_json = decrypt_uid(encrypted_data, rsa_private_key)

    if decrypted_json:
        print(json.dumps(decrypted_json, indent=4))
