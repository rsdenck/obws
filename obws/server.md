bws funcionando. O servidor responde "falha na descriptografia" porque a chave privada X25519 em /opt/bws/ws/server_x25519.key nao corresponde a chave publica embutida no bws.

Copie este arquivo para o servidor:

-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VuBCIEILCNHIDBnbnrhrxWAdUeVAxuTWiDSOKJpkzHr07cYnVI
-----END PRIVATE KEY-----

Apos isso, a descriptografia funcionara e os dados serao salvos no SQLite.
