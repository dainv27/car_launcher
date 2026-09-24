# Dev device-attestation CA (SELF_SIGNED_PKI)

Local-only credentials for exercising `vehicle-service` device enrollment against
a **dev** backend. Not for staging or production.

| File | Committed? | Purpose |
|---|---|---|
| `dev-device-ca.pem` | yes | CA public cert. Install as a backend trust anchor. |
| `dev-device-ca.key` | **no** (gitignored) | CA private key. Only needed to re-mint the bootstrap cert. Keep offline. |
| `../../assets/attestation/app-bootstrap.pem` | yes | App-bootstrap client cert, issued by this CA. Bundled in the APK. |
| `../../assets/attestation/app-bootstrap.key` | yes | App-bootstrap key (PKCS#8). Shared by every install by design. Bundled. |
| `../../assets/attestation/dev-device-ca.pem` | yes | Same CA cert, bundled so the app can send it in the chain if needed. |

## Backend step (do this on the dev server)

`vehicle-service` loads every `*.pem` under its configured
`vehicle-service.attestation.trust-anchors` (`classpath:attestation/*.pem`) as a
trust anchor — additively, so the real `device-ca.pem` keeps working. Add the dev
CA and redeploy:

```
cp dev-device-ca.pem <vehicle_service>/src/main/resources/attestation/
```

Until this is deployed, `POST /public-api/v1/devices/enroll` returns
`400 "chain does not validate to a trusted root"`.

## Regenerating (key rotation)

```
openssl ecparam -name prime256v1 -genkey -noout -out dev-device-ca.key
openssl req -x509 -new -key dev-device-ca.key -sha256 -days 3650 \
  -subj "/O=202corp/OU=vehicle-service/CN=202corp Dev Device CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" -out dev-device-ca.pem

openssl ecparam -name prime256v1 -genkey -noout -out bootstrap.key
openssl req -new -key bootstrap.key \
  -subj "/O=202corp/OU=car_launcher/CN=car_launcher app-bootstrap" -out bootstrap.csr
printf "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n" > v3.ext
openssl x509 -req -in bootstrap.csr -CA dev-device-ca.pem -CAkey dev-device-ca.key \
  -CAcreateserial -days 3650 -sha256 -extfile v3.ext -out app-bootstrap.pem
openssl pkcs8 -topk8 -nocrypt -in bootstrap.key -out app-bootstrap.key
# move app-bootstrap.{pem,key} + dev-device-ca.pem -> assets/attestation/
```
