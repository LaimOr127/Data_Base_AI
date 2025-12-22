// SiYuan - Refactor your thinking
// Copyright (c) 2020-present, b3log.org
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

package model

import (
	"crypto/rand"
	"net/http"
	"sync"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/siyuan-note/logging"
)

type Account struct {
	Username string
	Password string
	Token    string
	Role     Role // 角色 пользователя
}
type AccountsMap map[string]*Account // username -> account
type SessionsMap map[string]string   // sessionID -> username
type ClaimsKeyType string

const (
	XAuthTokenKey = "X-Auth-Token"

	SessionIdCookieName = "publish-visitor-session-id"

	ClaimsContextKey = "claims"

	iss = "siyuan-publish-reverse-proxy-server"
	sub = "publish"
	aud = "siyuan-kernel"

	ClaimsKeyRole string = "role"
)

var (
	accountsMap = AccountsMap{}
	sessionsMap = SessionsMap{}
	sessionLock = sync.Mutex{}

	jwtKey = make([]byte, 32)
)

func GetBasicAuthAccount(username string) *Account {
	return accountsMap[username]
}

func GetBasicAuthUsernameBySessionID(sessionID string) string {
	return sessionsMap[sessionID]
}

func GetNewSessionID() string {
	sessionID := uuid.New().String()
	return sessionID
}

func AddSession(sessionID, username string) {
	sessionLock.Lock()
	defer sessionLock.Unlock()
	sessionsMap[sessionID] = username
}

func DeleteSession(sessionID string) {
	sessionLock.Lock()
	defer sessionLock.Unlock()
	delete(sessionsMap, sessionID)
}

func InitAccounts() {
	accountsMap = AccountsMap{
		"": &Account{Role: RoleVisitor}, // 匿名用户
	}

	// Проверяем, что Publish.Auth существует
	if Conf.Publish == nil || Conf.Publish.Auth == nil {
		logging.LogWarnf("Publish.Auth is nil, no accounts will be loaded")
		InitJWT()
		return
	}

	accountCount := 0
	for _, account := range Conf.Publish.Auth.Accounts {
		if account == nil {
			continue
		}

		// Преобразуем строковую роль в Role
		var role Role = RoleReader // По умолчанию Reader
		switch account.Role {
		case "administrator", "admin":
			role = RoleAdministrator
		case "editor", "edit":
			role = RoleEditor
		case "reader", "read":
			role = RoleReader
		case "visitor", "guest":
			role = RoleVisitor
		default:
			// Если роль не указана, определяем по умолчанию
			if account.Username == "guest" {
				role = RoleVisitor
			} else {
				role = RoleEditor // По умолчанию Editor для обычных пользователей
			}
		}

		if account.Username == "" {
			logging.LogWarnf("Skipping account with empty username")
			continue
		}

		accountsMap[account.Username] = &Account{
			Username: account.Username,
			Password: account.Password,
			Role:     role,
		}
		accountCount++
	}

	logging.LogInfof("Initialized %d user accounts for login", accountCount)
	InitJWT()
}

func InitJWT() {
	if _, err := rand.Read(jwtKey); err != nil {
		logging.LogErrorf("generate JWT signing key failed: %s", err)
		return
	}

	for username, account := range accountsMap {
		// Используем роль из аккаунта, если не указана - по умолчанию RoleReader
		role := account.Role
		if role == 0 && username != "" {
			// Если роль не установлена, используем RoleReader
			role = RoleReader
		}

		// REF: https://golang-jwt.github.io/jwt/usage/create/
		t := jwt.NewWithClaims(
			jwt.SigningMethodHS256,
			jwt.MapClaims{
				"iss": iss,
				"sub": sub,
				"aud": aud,
				"jti": username,

				ClaimsKeyRole: role,
			},
		)
		if token, err := t.SignedString(jwtKey); err != nil {
			logging.LogErrorf("JWT signature failed: %s", err)
			return
		} else {
			account.Token = token
		}
	}
}

func ParseJWT(tokenString string) (*jwt.Token, error) {
	// REF: https://golang-jwt.github.io/jwt/usage/parse/
	return jwt.Parse(
		tokenString,
		func(token *jwt.Token) (interface{}, error) {
			return jwtKey, nil
		},
		jwt.WithIssuer(iss),
		jwt.WithSubject(sub),
		jwt.WithAudience(aud),
	)
}

func ParseXAuthToken(r *http.Request) *jwt.Token {
	tokenString := r.Header.Get(XAuthTokenKey)
	if tokenString != "" {
		if token, err := ParseJWT(tokenString); err != nil {
			logging.LogErrorf("JWT parse failed: %s", err)
		} else {
			return token
		}
	}
	return nil
}

func GetTokenClaims(token *jwt.Token) jwt.MapClaims {
	return token.Claims.(jwt.MapClaims)
}

func GetClaimRole(claims jwt.MapClaims) Role {
	if role := claims[ClaimsKeyRole]; role != nil {
		return Role(role.(float64))
	}
	return RoleVisitor
}
