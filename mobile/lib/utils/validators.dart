// Validation utilities for Shadow app
class Validators {
  // Validate Solana public key (base58, 32-44 chars)
  static bool isValidPubkey(String pubkey) {
    if (pubkey.length < 32 || pubkey.length > 44) {
      return false;
    }
    
    // Base58 characters: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
    final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    return base58Regex.hasMatch(pubkey);
  }
  
  // Validate domain name
  static bool isValidDomain(String domain) {
    if (domain.isEmpty || domain.length > 253) {
      return false;
    }
    
    // Domain regex: alphanumeric, hyphens, dots
    final domainRegex = RegExp(r'^[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)*$');
    return domainRegex.hasMatch(domain.toLowerCase());
  }
  
  // Validate IPFS CID
  static bool isValidIPFSCid(String cid) {
    if (cid.isEmpty) {
      return false;
    }
    
    // Basic CID validation (starts with Qm for v0 or bafy for v1)
    return cid.startsWith('Qm') || cid.startsWith('bafy') || cid.startsWith('ipfs://');
  }
  
  // Validate search query
  static bool isValidSearchQuery(String query) {
    if (query.isEmpty || query.length > 200) {
      return false;
    }
    
    // No special characters that could cause issues
    final invalidChars = RegExp("[<>\"']");
    return !invalidChars.hasMatch(query);
  }
  
  // Validate password strength
  static bool isStrongPassword(String password) {
    if (password.length < 8) {
      return false;
    }
    
    // At least one uppercase, one lowercase, one number
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    
    return hasUpper && hasLower && hasNumber;
  }
  
  // Sanitize input
  static String sanitizeInput(String input) {
    // Remove potentially dangerous characters
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .trim();
  }
  
  // Format wallet address for display
  static String formatWalletAddress(String address) {
    if (address.length <= 8) {
      return address;
    }
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }
  
  // Validate URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  // Extract domain from URL
  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }
}

