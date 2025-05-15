# Authenticate with PKI certificate

Access secured portals using a certificate.

![Image of Authenticate with PKI certificate sample](authenticate-with-pki-certificate-1.png)

## Use case

PKI (Public Key Infrastructure) is a certificate authentication method to secure resources without requiring users to remember passwords. Government agencies commonly issue smart cards using PKI to access computer systems.

## How to use the sample

1. Enter the URL to your PKI-secured portal.
2. Click the connect button to search for web maps stored on the portal.
3. You will be prompted to browse for a certificate and enter a password.
4. If you authenticate successfully, the portal item results will be displayed in the list.
5. Select a web map item to display it in the map view.

## How it works

1. The `AuthenticationManager` object is configured with a challenge handler that will prompt for a PKI certificate if a secure resource is encountered.
2. When a search for portal items is performed against a PKI-secured portal, the `Authenticator` creates a `NetworkCredential` from the information entered by the user.
3. If the user authenticates, the search returns a list of web maps (`PortalItem`) and the user can select one to display as a `Map`.

## Relevant API

* ArcGISEnvironment
* AuthenticationManager
* Authenticator
* Portal

## Additional information

ArcGIS Enterprise requires special configuration to enable support for PKI. See [Using Windows Active Directory and PKI to secure access to your portal](https://enterprise.arcgis.com/en/portal/latest/administer/windows/using-windows-active-directory-and-pki-to-secure-access-to-your-portal.htm) and [Use LDAP and PKI to secure access to your portal](https://enterprise.arcgis.com/en/portal/latest/administer/windows/use-ldap-and-pki-to-secure-access-to-your-portal.htm) in *Portal for ArcGIS*.

⚠ **NOTE**: Certificates installed on iOS are not available to user apps. Therefore, you will be prompted to browse for a certificate file when accessing PKI secured ArcGIS resources.

⚠ **NOTE**: Ensure that PKI certificates are available on the iOS device or storage drives, allowing you to browse for a certificate file when accessing PKI secured ArcGIS resources.

## Tags

authentication, certificate, login, passwordless, PKI, smartcard, store, X509
