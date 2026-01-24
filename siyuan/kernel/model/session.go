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
	"image/color"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/88250/gulu"
	ginSessions "github.com/gin-contrib/sessions"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/siyuan-note/logging"
	"github.com/siyuan-note/siyuan/kernel/util"
	"github.com/steambap/captcha"
	"golang.org/x/crypto/bcrypt"
)

var (
	BasicAuthHeaderKey   = "WWW-Authenticate"
	BasicAuthHeaderValue = "Basic realm=\"SiYuan Authorization Require\", charset=\"UTF-8\""
)

func LogoutAuth(c *gin.Context) {
	ret := gulu.Ret.NewResult()
	defer c.JSON(http.StatusOK, ret)

	if "" == Conf.AccessAuthCode {
		ret.Code = -1
		ret.Msg = Conf.Language(86)
		ret.Data = map[string]interface{}{"closeTimeout": 5000}
		return
	}

	session := util.GetSession(c)
	util.RemoveWorkspaceSession(session)
	if err := session.Save(c); err != nil {
		logging.LogErrorf("saves session failed: " + err.Error())
		ret.Code = -1
		ret.Msg = "save session failed"
	}
}

func LoginAuth(c *gin.Context) {
	ret := gulu.Ret.NewResult()
	defer c.JSON(http.StatusOK, ret)

	arg, ok := util.JsonArg(c, ret)
	if !ok {
		return
	}

	var inputCaptcha string
	session := util.GetSession(c)
	workspaceSession := util.GetWorkspaceSession(session)
	if util.NeedCaptcha() {
		captchaArg := arg["captcha"]
		if nil == captchaArg {
			ret.Code = 1
			ret.Msg = Conf.Language(21)
			logging.LogWarnf("invalid captcha")
			return
		}
		inputCaptcha = captchaArg.(string)
		if "" == inputCaptcha {
			ret.Code = 1
			ret.Msg = Conf.Language(21)
			logging.LogWarnf("invalid captcha")
			return
		}

		if strings.ToLower(workspaceSession.Captcha) != strings.ToLower(inputCaptcha) {
			ret.Code = 1
			ret.Msg = Conf.Language(22)
			logging.LogWarnf("invalid captcha")

			workspaceSession.Captcha = gulu.Rand.String(7) // https://github.com/siyuan-note/siyuan/issues/13147
			if err := session.Save(c); err != nil {
				logging.LogErrorf("save session failed: " + err.Error())
				c.Status(http.StatusInternalServerError)
				return
			}
			return
		}
	}

	// Проверка входа по логину/паролю
	// Работает независимо от publish.auth.enable, так как используется для основного входа
	if usernameArg, hasUsername := arg["username"]; hasUsername && usernameArg != nil {
		username := strings.TrimSpace(usernameArg.(string))
		passwordArg, hasPassword := arg["password"]

		if !hasPassword || passwordArg == nil {
			ret.Code = -1
			ret.Msg = "Введите пароль"
			util.WrongAuthCount++
			workspaceSession.Captcha = gulu.Rand.String(7)
			if err := session.Save(c); err != nil {
				logging.LogErrorf("save session failed: " + err.Error())
			}
			return
		}

		password := strings.TrimSpace(passwordArg.(string))
		if "" == username || "" == password {
			ret.Code = -1
			ret.Msg = "Введите логин и пароль"
			util.WrongAuthCount++
			workspaceSession.Captcha = gulu.Rand.String(7)
			if err := session.Save(c); err != nil {
				logging.LogErrorf("save session failed: " + err.Error())
			}
			return
		}

		// Проверяем аккаунт (независимо от publish.auth.enable)
		account := GetBasicAuthAccount(username)
		logging.LogInfof("Login attempt: username=[%s], account found=[%v], publish.auth.enable=[%v]", username, account != nil, Conf.Publish != nil && Conf.Publish.Auth != nil && Conf.Publish.Auth.Enable)

		if account == nil {
			// Аккаунт не найден
			ret.Code = -1
			ret.Msg = "Неверный логин или пароль"
			logging.LogWarnf("invalid username [%s] [ip=%s] - account not found", username, util.GetRemoteAddr(c.Request))
			util.WrongAuthCount++
			workspaceSession.Captcha = gulu.Rand.String(7)
			if err := session.Save(c); err != nil {
				logging.LogErrorf("save session failed: " + err.Error())
			}
			return
		}

		if account.Username == "" {
			// Аккаунт с пустым именем (анонимный)
			ret.Code = -1
			ret.Msg = "Неверный логин или пароль"
			logging.LogWarnf("invalid username [%s] [ip=%s] - empty account username", username, util.GetRemoteAddr(c.Request))
			util.WrongAuthCount++
			workspaceSession.Captcha = gulu.Rand.String(7)
			if err := session.Save(c); err != nil {
				logging.LogErrorf("save session failed: " + err.Error())
			}
			return
		}

		// Проверяем пароль (поддерживаем как bcrypt хэш, так и открытый текст для обратной совместимости)
		passwordMatch := false
		if strings.HasPrefix(account.Password, "$2a$") || strings.HasPrefix(account.Password, "$2b$") {
			// Это bcrypt хэш
			if err := bcrypt.CompareHashAndPassword([]byte(account.Password), []byte(password)); err == nil {
				passwordMatch = true
			}
		} else {
			// Открытый текст (для обратной совместимости)
			passwordMatch = account.Password == password
		}
		
		if !passwordMatch {
			// Неверный пароль
			ret.Code = -1
			ret.Msg = "Неверный логин или пароль"
			logging.LogWarnf("invalid password for user [%s] [ip=%s]", username, util.GetRemoteAddr(c.Request))
			util.WrongAuthCount++
			workspaceSession.Captcha = gulu.Rand.String(7)
			if err := session.Save(c); err != nil {
				logging.LogErrorf("save session failed: " + err.Error())
			}
			return
		}

		logging.LogInfof("Login success for user [%s] with role [%d] [ip=%s]", username, account.Role, util.GetRemoteAddr(c.Request))

		// Успешный вход по логину/паролю
		workspaceSession.UserLogin = username
		// НЕ устанавливаем AccessAuthCode при входе по логину/паролю
		// Роль будет определяться из аккаунта, а не из AccessAuthCode
		// workspaceSession.AccessAuthCode = Conf.AccessAuthCode
		util.WrongAuthCount = 0
		workspaceSession.Captcha = gulu.Rand.String(7)

		maxAge := 0
		if rememberMe, ok := arg["rememberMe"].(bool); ok && rememberMe {
			maxAge = 60 * 60 * 24 * 30 // 30 days
		}
		ginSessions.Default(c).Options(ginSessions.Options{
			Path:     "/",
			Secure:   util.SSL,
			HttpOnly: true,
			MaxAge:   maxAge,
			SameSite: http.SameSiteLaxMode,
		})
		if err := session.Save(c); err != nil {
			logging.LogErrorf("save session failed: " + err.Error())
			ret.Code = -1
			ret.Msg = "save session failed"
			return
		}
		ret.Code = 0
		ret.Msg = "OK"
		ret.Data = map[string]interface{}{"role": account.Role}
		logging.LogInfof("Login successful, session saved for user [%s]", username)
		return
	}

	// Проверка AccessAuthCode (старый способ)
	authCodeArg, hasAuthCode := arg["authCode"]
	if !hasAuthCode || authCodeArg == nil {
		// Если нет ни логина/пароля, ни AccessAuthCode - ошибка
		ret.Code = -1
		ret.Msg = "Введите код доступа или логин/пароль"
		util.WrongAuthCount++
		workspaceSession.Captcha = gulu.Rand.String(7)
		if err := session.Save(c); err != nil {
			logging.LogErrorf("save session failed: " + err.Error())
		}
		return
	}

	authCode, ok := authCodeArg.(string)
	if !ok {
		ret.Code = -1
		ret.Msg = "Неверный формат кода доступа"
		util.WrongAuthCount++
		workspaceSession.Captcha = gulu.Rand.String(7)
		if err := session.Save(c); err != nil {
			logging.LogErrorf("save session failed: " + err.Error())
		}
		return
	}

	authCode = strings.TrimSpace(authCode)
	authCode = util.RemoveInvalid(authCode)

	if Conf.AccessAuthCode != authCode {
		ret.Code = -1
		ret.Msg = Conf.Language(83)
		logging.LogWarnf("invalid auth code [ip=%s]", util.GetRemoteAddr(c.Request))

		util.WrongAuthCount++
		workspaceSession.Captcha = gulu.Rand.String(7)
		if util.NeedCaptcha() {
			ret.Code = 1 // 需要渲染验证码
		}

		if err := session.Save(c); err != nil {
			logging.LogErrorf("save session failed: " + err.Error())
			session.Clear(c)
			ret.Code = 1
			ret.Msg = Conf.Language(258)
			return
		}
		return
	}

	workspaceSession.AccessAuthCode = authCode
	util.WrongAuthCount = 0
	workspaceSession.Captcha = gulu.Rand.String(7)

	maxAge := 0 // Default session expiration (browser session)
	if rememberMe, ok := arg["rememberMe"].(bool); ok && rememberMe {
		// Add a 'Remember me' checkbox when logging in to save a session https://github.com/siyuan-note/siyuan/pull/14964
		maxAge = 60 * 60 * 24 * 30 // 30 days
	}
	ginSessions.Default(c).Options(ginSessions.Options{
		Path:     "/",
		Secure:   util.SSL,
		MaxAge:   maxAge,
		HttpOnly: true,
	})

	logging.LogInfof("auth success [ip=%s, maxAge=%d]", util.GetRemoteAddr(c.Request), maxAge)
	if err := session.Save(c); err != nil {
		logging.LogErrorf("save session failed: " + err.Error())
		c.Status(http.StatusInternalServerError)
		return
	}
}

func GetCaptcha(c *gin.Context) {
	img, err := captcha.New(100, 26, func(options *captcha.Options) {
		options.CharPreset = "ABCDEFGHKLMNPQRSTUVWXYZ23456789"
		options.Noise = 0.5
		options.CurveNumber = 0
		options.BackgroundColor = color.White
	})
	if err != nil {
		logging.LogErrorf("generates captcha failed: " + err.Error())
		c.Status(http.StatusInternalServerError)
		return
	}

	session := util.GetSession(c)
	workspaceSession := util.GetWorkspaceSession(session)
	workspaceSession.Captcha = img.Text
	if err = session.Save(c); err != nil {
		logging.LogErrorf("save session failed: " + err.Error())
		c.Status(http.StatusInternalServerError)
		return
	}

	if err = img.WriteImage(c.Writer); err != nil {
		logging.LogErrorf("writes captcha image failed: " + err.Error())
		c.Status(http.StatusInternalServerError)
		return
	}
	c.Status(http.StatusOK)
}

func CheckReadonly(c *gin.Context) {
	if util.ReadOnly || IsReadOnlyRole(GetGinContextRole(c)) {
		result := util.NewResult()
		result.Code = -1
		result.Msg = Conf.Language(34)
		result.Data = map[string]interface{}{"closeTimeout": 5000}
		c.JSON(http.StatusOK, result)
		c.Abort()
		return
	}
}

func CheckAuth(c *gin.Context) {
	// 已通过 JWT 认证
	if role := GetGinContextRole(c); IsValidRole(role, []Role{
		RoleAdministrator,
		RoleEditor,
		RoleReader,
	}) {
		c.Next()
		return
	}

	// 通过 API token (header: Authorization)
	if authHeader := c.GetHeader("Authorization"); "" != authHeader {
		var token string
		if strings.HasPrefix(authHeader, "Token ") {
			token = strings.TrimPrefix(authHeader, "Token ")
		} else if strings.HasPrefix(authHeader, "token ") {
			token = strings.TrimPrefix(authHeader, "token ")
		} else if strings.HasPrefix(authHeader, "Bearer ") {
			token = strings.TrimPrefix(authHeader, "Bearer ")
		} else if strings.HasPrefix(authHeader, "bearer ") {
			token = strings.TrimPrefix(authHeader, "bearer ")
		}

		if "" != token {
			if Conf.Api.Token == token {
				c.Set(RoleContextKey, RoleAdministrator)
				c.Next()
				return
			}

			c.JSON(http.StatusUnauthorized, map[string]interface{}{"code": -1, "msg": "Auth failed [header: Authorization]"})
			c.Abort()
			return
		}
	}

	// 通过 API token (query-params: token)
	if token := c.Query("token"); "" != token {
		if Conf.Api.Token == token {
			c.Set(RoleContextKey, RoleAdministrator)
			c.Next()
			return
		}

		c.JSON(http.StatusUnauthorized, map[string]interface{}{"code": -1, "msg": "Auth failed [query: token]"})
		c.Abort()
		return
	}

	//logging.LogInfof("check auth for [%s]", c.Request.RequestURI)

	// ОБЯЗАТЕЛЬНАЯ АВТОРИЗАЦИЯ - AccessAuthCode всегда должен быть установлен
	// Убраны все исключения для localhost - теперь все требуют авторизацию
	// Убраны все исключения для localhost - теперь все требуют авторизацию
	if "" == Conf.AccessAuthCode {
		// Если AccessAuthCode не установлен, перенаправляем на страницу авторизации
		// Это не должно происходить, так как код генерируется автоматически при старте
		if "GET" == c.Request.Method && !c.IsWebsocket() {
			location := url.URL{}
			queryParams := url.Values{}
			queryParams.Set("to", c.Request.URL.String())
			location.RawQuery = queryParams.Encode()
			location.Path = "/check-auth"
			c.Redirect(http.StatusFound, location.String())
			c.Abort()
			return
		}
		c.JSON(http.StatusUnauthorized, map[string]interface{}{"code": -1, "msg": "Access authorization code is required. Please authenticate first.\n\nТребуется код авторизации. Пожалуйста, авторизуйтесь."})
		c.Abort()
		return
	}

	// Разрешаем только страницу авторизации и необходимые статические файлы
	// Все остальное требует авторизацию, включая localhost
	if strings.HasPrefix(c.Request.RequestURI, "/check-auth") {
		c.Next()
		return
	}

	// Разрешаем только статические файлы для страницы авторизации
	if strings.HasPrefix(c.Request.RequestURI, "/appearance/") {
		// Разрешаем только языки и темы для страницы авторизации
		if strings.Contains(c.Request.RequestURI, "/langs/") || strings.Contains(c.Request.RequestURI, "/themes/") {
			c.Next()
			return
		}
	}

	// Для статических файлов страницы авторизации
	if strings.HasPrefix(c.Request.RequestURI, "/stage/build/export/") {
		c.Next()
		return
	}

	// ВСЕ остальные запросы требуют авторизацию, включая localhost
	// Убраны все исключения для localhost - теперь обязательная авторизация для всех

	// 通过 Cookie
	session := util.GetSession(c)
	workspaceSession := util.GetWorkspaceSession(session)

	// СНАЧАЛА проверяем вход по логину/паролю через сессию (это приоритетнее для пользователей)
	// Проверка входа по логину/паролю через сессию
	// Если пользователь вошел по логину/паролю, его роль определяется из аккаунта, а не из AccessAuthCode
	if Conf.Publish != nil && Conf.Publish.Auth != nil && Conf.Publish.Auth.Enable && workspaceSession.UserLogin != "" {
		account := GetBasicAuthAccount(workspaceSession.UserLogin)
		if account != nil && account.Username != "" {
			c.Set(RoleContextKey, account.Role)
			logging.LogDebugf("Auth via session: user [%s] role [%d] for [%s]", workspaceSession.UserLogin, account.Role, c.Request.RequestURI)
			c.Next()
			return
		} else {
			logging.LogWarnf("Session user [%s] not found in accounts for [%s]", workspaceSession.UserLogin, c.Request.RequestURI)
		}
	}

	// Затем проверяем AccessAuthCode (только для случаев без логина/пароля)
	// AccessAuthCode дает администраторские права только если пользователь НЕ вошел по логину/паролю
	if workspaceSession.AccessAuthCode == Conf.AccessAuthCode && workspaceSession.UserLogin == "" {
		c.Set(RoleContextKey, RoleAdministrator)
		c.Next()
		return
	}

	// 通过 BasicAuth (header: Authorization)
	if username, password, ok := c.Request.BasicAuth(); ok {
		// 使用访问授权码作为密码
		if util.WorkspaceName == username && Conf.AccessAuthCode == password {
			c.Set(RoleContextKey, RoleAdministrator)
			c.Next()
			return
		}

		// Проверка пользователей из Publish.Auth.Accounts
		if Conf.Publish != nil && Conf.Publish.Auth != nil && Conf.Publish.Auth.Enable {
			account := GetBasicAuthAccount(username)
			if account != nil && account.Username != "" {
				// Проверяем пароль (поддерживаем как bcrypt хэш, так и открытый текст)
				passwordMatch := false
				if strings.HasPrefix(account.Password, "$2a$") || strings.HasPrefix(account.Password, "$2b$") {
					// Это bcrypt хэш
					if err := bcrypt.CompareHashAndPassword([]byte(account.Password), []byte(password)); err == nil {
						passwordMatch = true
					}
				} else {
					// Открытый текст (для обратной совместимости)
					passwordMatch = account.Password == password
				}
				
				if passwordMatch {
					// Устанавливаем роль пользователя
					c.Set(RoleContextKey, account.Role)
					// Сохраняем в сессии для последующих запросов
					workspaceSession.UserLogin = username
					if err := session.Save(c); err != nil {
						logging.LogErrorf("save session failed: %s", err)
					}
					c.Next()
					return
				}
			}
		}
	}

	// WebDAV BasicAuth Authenticate
	if strings.HasPrefix(c.Request.RequestURI, "/webdav") ||
		strings.HasPrefix(c.Request.RequestURI, "/caldav") ||
		strings.HasPrefix(c.Request.RequestURI, "/carddav") {
		c.Header(BasicAuthHeaderKey, BasicAuthHeaderValue)
		c.AbortWithStatus(http.StatusUnauthorized)
		return
	}

	// 跳过访问授权页
	if "/check-auth" == c.Request.URL.Path {
		c.Next()
		return
	}

	if workspaceSession.AccessAuthCode != Conf.AccessAuthCode {
		userAgentHeader := c.GetHeader("User-Agent")
		if strings.HasPrefix(userAgentHeader, "SiYuan/") || strings.HasPrefix(userAgentHeader, "Mozilla/") {
			if "GET" != c.Request.Method || c.IsWebsocket() {
				c.JSON(http.StatusUnauthorized, map[string]interface{}{"code": -1, "msg": Conf.Language(156)})
				c.Abort()
				return
			}

			location := url.URL{}
			queryParams := url.Values{}
			queryParams.Set("to", c.Request.URL.String())
			location.RawQuery = queryParams.Encode()
			location.Path = "/check-auth"

			c.Redirect(http.StatusFound, location.String())
			c.Abort()
			return
		}

		c.JSON(http.StatusUnauthorized, map[string]interface{}{"code": -1, "msg": "Auth failed [session]"})
		c.Abort()
		return
	}

	c.Set(RoleContextKey, RoleAdministrator)
	c.Next()
}

func CheckAdminRole(c *gin.Context) {
	if IsAdminRoleContext(c) {
		c.Next()
	} else {
		logging.LogWarnf("Forbidden (admin required): role=%d path=%s", GetGinContextRole(c), c.Request.URL.Path)
		c.AbortWithStatus(http.StatusForbidden)
	}
}

func CheckEditRole(c *gin.Context) {
	if IsValidRole(GetGinContextRole(c), []Role{
		RoleAdministrator,
		RoleEditor,
	}) {
		c.Next()
	} else {
		logging.LogWarnf("Forbidden (edit required): role=%d path=%s", GetGinContextRole(c), c.Request.URL.Path)
		c.AbortWithStatus(http.StatusForbidden)
	}
}

func CheckReadRole(c *gin.Context) {
	if IsValidRole(GetGinContextRole(c), []Role{
		RoleAdministrator,
		RoleEditor,
		RoleReader,
	}) {
		c.Next()
	} else {
		logging.LogWarnf("Forbidden (read required): role=%d path=%s", GetGinContextRole(c), c.Request.URL.Path)
		c.AbortWithStatus(http.StatusForbidden)
	}
}

var timingAPIs = map[string]int{
	"/api/search/fullTextSearchBlock": 200, // Monitor the search performance and suggest solutions https://github.com/siyuan-note/siyuan/issues/7873
}

func Timing(c *gin.Context) {
	p := c.Request.URL.Path
	tip, ok := timingAPIs[p]
	if !ok {
		c.Next()
		return
	}

	timing := 15 * 1000
	if timingEnv := os.Getenv("SIYUAN_PERFORMANCE_TIMING"); "" != timingEnv {
		val, err := strconv.Atoi(timingEnv)
		if err == nil {
			timing = val
		}
	}

	now := time.Now().UnixMilli()
	c.Next()
	elapsed := int(time.Now().UnixMilli() - now)
	if timing < elapsed {
		logging.LogWarnf("[%s] elapsed [%dms]", c.Request.RequestURI, elapsed)
		util.PushMsg(Conf.Language(tip), 7000)
	}
}

func Recover(c *gin.Context) {
	defer logging.Recover()
	c.Next()
}

var (
	requestingLock = sync.Mutex{}
	requesting     = map[string]*sync.Mutex{}
)

func ControlConcurrency(c *gin.Context) {
	if websocket.IsWebSocketUpgrade(c.Request) {
		c.Next()
		return
	}

	reqPath := c.Request.URL.Path

	// Improve the concurrency of the kernel data reading interfaces https://github.com/siyuan-note/siyuan/issues/10149
	if strings.HasPrefix(reqPath, "/stage/") ||
		strings.HasPrefix(reqPath, "/assets/") ||
		strings.HasPrefix(reqPath, "/emojis/") ||
		strings.HasPrefix(reqPath, "/plugins/") ||
		strings.HasPrefix(reqPath, "/public/") ||
		strings.HasPrefix(reqPath, "/snippets/") ||
		strings.HasPrefix(reqPath, "/templates/") ||
		strings.HasPrefix(reqPath, "/widgets/") ||
		strings.HasPrefix(reqPath, "/appearance/") ||
		strings.HasPrefix(reqPath, "/export/") ||
		strings.HasPrefix(reqPath, "/history/") ||
		strings.HasPrefix(reqPath, "/api/query/") ||
		strings.HasPrefix(reqPath, "/api/search/") ||
		strings.HasPrefix(reqPath, "/api/network/") ||
		strings.HasPrefix(reqPath, "/api/broadcast/") ||
		strings.HasPrefix(reqPath, "/es/") {
		c.Next()
		return
	}

	parts := strings.Split(reqPath, "/")
	function := parts[len(parts)-1]
	if strings.HasPrefix(function, "get") ||
		strings.HasPrefix(function, "list") ||
		strings.HasPrefix(function, "search") ||
		strings.HasPrefix(function, "render") ||
		strings.HasPrefix(function, "ls") {
		c.Next()
		return
	}

	requestingLock.Lock()
	mutex := requesting[reqPath]
	if nil == mutex {
		mutex = &sync.Mutex{}
		requesting[reqPath] = mutex
	}
	requestingLock.Unlock()

	mutex.Lock()
	defer mutex.Unlock()
	c.Next()
}
