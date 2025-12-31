// backend/auth/validate_jwt.go
// Production-ready Gin middleware for Auth0 JWT validation using JWKS
// Run with: go mod init auth-backend; go get github.com/gin-gonic/gin github.com/golang-jwt/jwt/v5 github.com/lestrrat-go/jwx/v2/jwk github.com/lestrrat-go/jwx/v2/jwt

package main

import (
  "context"
  "fmt"
  "net/http"
  "strings"

  "github.com/gin-gonic/gin"
  "github.com/golang-jwt/jwt/v5"
  "github.com/lestrrat-go/jwx/v2/jwk"
)

const (
  auth0Domain = "your-domain.auth0.com" // Replace
  audience    = "your-audience"         // Replace
)

func validateJWTMiddleware() gin.HandlerFunc {
  return func(c *gin.Context) {
    authHeader := c.GetHeader("Authorization")
    if authHeader == "" {
      c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
      c.Abort()
      return
    }
    tokenString := strings.TrimPrefix(authHeader, "Bearer ")
    token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
      if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
        return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
      }
      kid, ok := token.Header["kid"].(string)
      if !ok {
        return nil, fmt.Errorf("kid header not found")
      }
      keySet, err := jwk.Fetch(context.Background(), fmt.Sprintf("https://%s/.well-known/jwks.json", auth0Domain))
      if err != nil {
        return nil, fmt.Errorf("failed to fetch JWKS: %w", err)
      }
      key, found := keySet.LookupKeyID(kid)
      if !found {
        return nil, fmt.Errorf("key %s not found", kid)
      }
      return key.Materialize(context.Background())
    })
    if err != nil || !token.Valid {
      c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
      c.Abort()
      return
    }
    claims, ok := token.Claims.(jwt.MapClaims)
    if !ok || claims["aud"] != audience {
      c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid audience"})
      c.Abort()
      return
    }
    c.Set("user_id", claims["sub"])
    c.Next()
  }
}

func main() {
  r := gin.Default()
  r.Use(validateJWTMiddleware())
  r.GET("/protected", func(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
      "message": "Protected endpoint accessed",
      "user_id": c.GetString("user_id"),
    })
  })
  r.Run(":8080")
}
