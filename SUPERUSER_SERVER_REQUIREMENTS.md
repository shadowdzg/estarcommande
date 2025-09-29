# Superuser Server Requirements Analysis

## Current Issue
The superuser role is getting **500 errors** when making API calls to fetch orders, while admin and assistant roles work fine.

## Root Cause Analysis

### 1. **Pagination Parameter Mismatch**
The Flutter app is sending different parameters for superuser vs other users:

**Regular Users (Admin/Assistant):**
```
GET /api/v1/commands?skip=0&take=10
```

**Superuser (Current Implementation):**
```
GET /api/v1/commands?limit=10&pageSize=10&userType=superuser&isSuperUser=true&cursor=page_0&offset=0&page=0
```

### 2. **Server-Side Requirements**

The server needs to handle **multiple pagination approaches** for superuser:

#### **Option A: Cursor-Based Pagination (Recommended)**
```javascript
// Server should support cursor-based pagination for superuser
app.get('/api/v1/commands', (req, res) => {
  const { limit, pageSize, userType, isSuperUser, cursor, offset, page } = req.query;
  
  if (userType === 'superuser' || isSuperUser === 'true') {
    // Use cursor-based pagination
    const limitValue = parseInt(limit) || parseInt(pageSize) || 10;
    const cursorValue = cursor || null;
    
    // Implement cursor-based query
    const query = buildCursorQuery(cursorValue, limitValue);
    // ... execute query
  } else {
    // Use regular skip/take pagination
    const skip = parseInt(req.query.skip) || 0;
    const take = parseInt(req.query.take) || 10;
    // ... execute regular query
  }
});
```

#### **Option B: Offset-Based Pagination**
```javascript
// Server should support offset-based pagination for superuser
if (userType === 'superuser') {
  const offset = parseInt(req.query.offset) || 0;
  const limit = parseInt(req.query.limit) || 10;
  
  // Use OFFSET/LIMIT in SQL query
  const query = `SELECT * FROM commands ORDER BY id OFFSET ${offset} LIMIT ${limit}`;
}
```

#### **Option C: Page-Based Pagination**
```javascript
// Server should support page-based pagination for superuser
if (userType === 'superuser') {
  const page = parseInt(req.query.page) || 0;
  const pageSize = parseInt(req.query.pageSize) || 10;
  const offset = page * pageSize;
  
  // Use calculated offset
  const query = `SELECT * FROM commands ORDER BY id OFFSET ${offset} LIMIT ${pageSize}`;
}
```

### 3. **Database Query Examples**

#### **For Cursor-Based Pagination:**
```sql
-- If cursor is provided, get records after the cursor
SELECT * FROM commands 
WHERE id > ? 
ORDER BY id 
LIMIT ?

-- If no cursor, get first page
SELECT * FROM commands 
ORDER BY id 
LIMIT ?
```

#### **For Offset-Based Pagination:**
```sql
SELECT * FROM commands 
ORDER BY id 
OFFSET ? 
LIMIT ?
```

### 4. **Role-Based Access Control**

The server should also handle superuser-specific permissions:

```javascript
// Check if user is superuser
const isSuperUser = req.user.role === 'superuser' || req.user.isSuperUser;

if (isSuperUser) {
  // Superuser can see all orders from all regions
  // No region filtering needed
} else {
  // Regular users see only their region's orders
  // Apply region filtering
}
```

### 5. **Error Handling**

The server should provide clear error messages:

```javascript
try {
  // Process superuser request
  const orders = await getOrdersForSuperuser(params);
  res.json({ data: orders, success: true });
} catch (error) {
  console.error('Superuser API Error:', error);
  res.status(500).json({ 
    error: 'Failed to fetch orders for superuser', 
    details: error.message,
    userType: 'superuser'
  });
}
```

## Implementation Steps

### 1. **Immediate Fix (Server-Side)**
Add support for superuser parameters in your existing `/api/v1/commands` endpoint:

```javascript
app.get('/api/v1/commands', authenticateToken, (req, res) => {
  const { 
    skip, take,           // Regular users
    limit, pageSize,      // Superuser
    userType, isSuperUser, // Superuser identification
    cursor, offset, page   // Superuser pagination
  } = req.query;

  // Determine user type
  const isSuper = userType === 'superuser' || isSuperUser === 'true' || req.user.isSuperUser;
  
  if (isSuper) {
    // Handle superuser pagination
    const limitValue = parseInt(limit) || parseInt(pageSize) || 10;
    const offsetValue = parseInt(offset) || (parseInt(page) || 0) * limitValue;
    
    // Query with offset/limit
    const query = `SELECT * FROM commands ORDER BY id OFFSET ${offsetValue} LIMIT ${limitValue}`;
    // Execute query...
  } else {
    // Handle regular pagination
    const skipValue = parseInt(skip) || 0;
    const takeValue = parseInt(take) || 10;
    
    // Query with skip/take
    const query = `SELECT * FROM commands ORDER BY id OFFSET ${skipValue} LIMIT ${takeValue}`;
    // Execute query...
  }
});
```

### 2. **Test the Fix**
After implementing the server changes, test with these requests:

**Superuser Request:**
```bash
curl -H "Authorization: Bearer <superuser_token>" \
  "http://estcommand.ddns.net:8080/api/v1/commands?limit=10&pageSize=10&userType=superuser&isSuperUser=true"
```

**Regular User Request:**
```bash
curl -H "Authorization: Bearer <admin_token>" \
  "http://estcommand.ddns.net:8080/api/v1/commands?skip=0&take=10"
```

### 3. **Expected Response Format**
Both should return the same format:
```json
{
  "data": [
    {
      "id": 1,
      "clientName": "Client Name",
      "productName": "Product Name",
      "quantity": 10,
      "status": "pending",
      // ... other fields
    }
  ],
  "total": 100,
  "page": 0,
  "pageSize": 10,
  "success": true
}
```

## Debugging Steps

1. **Check Server Logs** when superuser makes requests
2. **Verify JWT Token** contains correct `issuper` field
3. **Test API directly** with curl/Postman using superuser token
4. **Compare requests** between working admin and failing superuser

## Summary

The server needs to:
1. ✅ **Accept multiple pagination parameters** (skip/take for regular users, limit/pageSize for superuser)
2. ✅ **Identify superuser requests** via `userType=superuser` or `isSuperUser=true` parameters
3. ✅ **Handle different pagination methods** (cursor, offset, page-based)
4. ✅ **Apply appropriate permissions** (superuser sees all orders, others see filtered)
5. ✅ **Return consistent response format** regardless of user type

Once these changes are implemented on the server, the superuser should work correctly with the Flutter app.
