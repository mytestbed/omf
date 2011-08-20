
How to test SSL part of server
==============================

openssl s_client -connect localhost:8001 -cert ~/.gcf/alice-cert.pem -key ~/.gcf/alice-key.pem -prexit

# Create a server
openssl s_server -accept 8001 -cert ~/.gcf/am-cert.pem -key ~/.gcf/am-key.pem -CAfile ~/.gcf/trusted_roots/CATedCACerts.pem -www