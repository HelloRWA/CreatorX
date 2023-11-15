import forge from 'node-forge'
import { ofetch } from "ofetch";
import { v4 as uuidv4 } from 'uuid';

export const generateEntitySecretCiphertext = (event) => {
  const config = useRuntimeConfig(event)
  const entitySecret = config.circleEntitySecret
  const publicKeyBase64 = config.circlePublicKeyBase64
  const publicKeyBuffer = Buffer.from(publicKeyBase64, 'base64')
  const publicKey = publicKeyBuffer.toString('utf-8')
  const thePublicKey = forge.pki.publicKeyFromPem(publicKey)
  const encryptedData = thePublicKey.encrypt(forge.util.hexToBytes(entitySecret), 'RSA-OAEP', {
    md: forge.md.sha256.create(),
    mgf1: {
      md: forge.md.sha256.create(),
    },
  })

  return forge.util.encode64(encryptedData)
}

export const createCircleWalletRequest = async (params, {path, method = 'POST', event}) => {
  const config = useRuntimeConfig(event)
  const idempotencyKey = uuidv4()
  const entitySecretCiphertext = generateEntitySecretCiphertext(event)
  const url = `https://api.circle.com${path}`
  const data = {
      headers: {
        Authorization: `Bearer ${config.circleApiKey}`
      },
      method,
  }
  if (method !== 'GET') {
    data.body = {
      idempotencyKey,
      entitySecretCiphertext,
      ...params,
    }
  }
  
  return ofetch(url, data)
}