import * as md5 from "blueimp-md5";
import {hideMessage, showMessage} from "../dialog/message";
import {Constants} from "../constants";
import {fetchPost} from "../util/fetch";
import {repos} from "./repos";
import {confirmDialog} from "../dialog/confirmDialog";
import {hasClosestByClassName} from "../protyle/util/hasClosest";
import {getEventName, isInIOS} from "../protyle/util/compatibility";
import {processSync} from "../dialog/processSystem";
import {needSubscribe} from "../util/needSubscribe";
import {syncGuide} from "../sync/syncGuide";
import {hideElements} from "../protyle/ui/hideElements";
import {getCloudURL, getIndexURL} from "./util/about";
import {iOSPurchase} from "../util/iOSPurchase";

const genSVGBG = () => {
    let html = "";
    const svgs: string[] = [];
    document.querySelectorAll("body > svg > defs > symbol").forEach((item) => {
        svgs.push(item.id);
    });
    Array.from({length: 45}, () => {
        const index = Math.floor(Math.random() * svgs.length);
        html += `<svg><use xlink:href="#${svgs[index]}"></use></svg>`;
        svgs.splice(index, 1);
    });
    return `<div class="fn__flex config-account__svg">${html}</div>`;
};

export const account = {
    element: undefined as Element,
    genHTML: (onlyPayHTML = false) => {
        // Элементы подписки удалены - приложение опенсорс, полный функционал бесплатно
        const payHTML = `<div class="b3-chip b3-chip--success"><svg><use xlink:href="#iconVIP"></use></svg>Полный функционал доступен (Open Source)</div>`;
        if (onlyPayHTML) {
            // Элементы подписки удалены
            return `<div class="fn__flex-1 fn__hr--b"></div>
<div class="b3-chip b3-chip--success"><svg><use xlink:href="#iconVIP"></use></svg>Полный функционал доступен (Open Source)</div>
<div class="fn__flex-1 fn__hr--b"></div>`;
        }
        if (window.siyuan.user) {
            let userTitlesHTML = "";
            if (window.siyuan.user.userTitles.length > 0) {
                userTitlesHTML = '<div class="b3-chips" style="position: absolute">';
                window.siyuan.user.userTitles.forEach((item) => {
                    userTitlesHTML += `<div class="b3-chip b3-chip--middle b3-chip--primary">${item.icon} ${item.name}</div>`;
                });
                userTitlesHTML += "</div>";
            }
            // Элементы подписки удалены - приложение опенсорс, полный функционал бесплатно
            let subscriptionHTML = `<div class="b3-chip b3-chip--success"><svg><use xlink:href="#iconVIP"></use></svg>Полный функционал доступен (Open Source)</div>`;
            let activeSubscriptionHTML = "";
            return `<div class="fn__flex config-account">
<div class="config-account__center">
    <div class="config-account__bg">
        <div class="config-account__cover" style="background-image: url(${window.siyuan.user.userHomeBImgURL})"></div>
        <a href="${getCloudURL("settings/avatar")}" class="config-account__avatar" style="background-image: url(${window.siyuan.user.userAvatarURL})" target="_blank"></a>
        <h1 class="config-account__name">
            <a target="_blank" class="fn__a" href="${getCloudURL("member/" + window.siyuan.user.userName)}">${window.siyuan.user.userName}</a>
            <span class="ft__on-surface ft__smaller">${0 === window.siyuan.config.cloudRegion ? "ld246.com" : "liuyun.io"}</span>
        </h1>
        ${userTitlesHTML}
    </div>
    <div class="config-account__info">
        <div class="fn__flex">
            <a class="b3-button b3-button--text${isIOS ? " fn__none" : ""}" href="${getCloudURL("settings")}" target="_blank">${window.siyuan.languages.manage}</a>
            <span class="fn__space${isIOS ? " fn__none" : ""}"></span>
            <button class="b3-button b3-button--cancel" id="logout">
                ${window.siyuan.languages.logout}
            </button>
            <span class="fn__space"></span>
            <button class="b3-button b3-button--cancel${window.siyuan.config.system.container === "ios" ? "" : " fn__none"}" id="deactivateUser">
                ${window.siyuan.languages.deactivateUser}
            </button>
            <span class="fn__flex-1"></span>
            <button class="b3-button b3-button--cancel b3-tooltips b3-tooltips__n" id="refresh" aria-label="${window.siyuan.languages.refresh}">
                <svg style="margin-right: 0"><use xlink:href="#iconRefresh"></use></svg>
            </button>
        </div>
        <div class="fn__hr--b"></div>
        <div class="fn__flex">  
            <label>
                ${window.siyuan.languages.accountDisplayTitle}
                <input class="b3-switch fn__flex-center" id="displayTitle" type="checkbox"${window.siyuan.config.account.displayTitle ? " checked" : ""}/>
            </label>
            <div class="fn__flex-1"></div>
            <label>
                ${window.siyuan.languages.accountDisplayVIP}
                <input class="b3-switch fn__flex-center" id="displayVIP" type="checkbox"${window.siyuan.config.account.displayVIP ? " checked" : ""}/>
            </label>
        </div>
    </div>
</div>
<div class="config-account__center config-account__center--text">
    <div class="fn__flex-1 fn__hr--b"></div>
    ${subscriptionHTML}
    <div class="fn__flex-1 fn__hr--b"></div>
    ${activeSubscriptionHTML}
</div></div>`;
        }
        return `<div class="fn__flex config-account">
<div class="b3-form__space config-account__center">
    <div class="config-account__form" id="form1">
        <div class="b3-form__icon">
            <svg class="b3-form__icon-icon"><use xlink:href="#iconAccount"></use></svg>
            <input id="userName" class="b3-text-field fn__block b3-form__icon-input" placeholder="${window.siyuan.languages.accountName}">
        </div>
        <div class="fn__hr--b"></div>
        <div class="b3-form__icon">
            <svg class="b3-form__icon-icon"><use xlink:href="#iconLock"></use></svg>
            <input type="password" id="userPassword" class="b3-text-field b3-form__icon-input fn__block" placeholder="${window.siyuan.languages.password}">
        </div>
        <div class="b3-form__img fn__none">
            <div class="fn__hr--b"></div>
            <img id="captchaImg" class="fn__pointer" style="top: 17px;height:26px">
            <input id="captcha" class="b3-text-field fn__block" placeholder="${window.siyuan.languages.captcha}">
        </div>
        <div class="fn__hr--b"></div>
        <button id="login" class="b3-button fn__block">${window.siyuan.languages.login}</button>
        <div class="fn__hr--b"></div>
        <div class="ft__center">
            <a href="${getCloudURL("forget-pwd")}" class="b3-button b3-button--cancel" target="_blank">${window.siyuan.languages.forgetPassword}</a>
            <span class="fn__space${window.siyuan.config.system.container === "ios" ? " fn__none" : ""}"></span>
            <a href="${getCloudURL("register")}" class="b3-button b3-button--cancel${window.siyuan.config.system.container === "ios" ? " fn__none" : ""}" target="_blank">${window.siyuan.languages.register}</a>
        </div>
    </div>
    <div class="fn__none config-account__form" id="form2">
        <div class="b3-form__icon">
            <svg class="b3-form__icon-icon"><use xlink:href="#iconLock"></use></svg>
            <input id="twofactorAuthCode" class="b3-text-field fn__block b3-form__icon-input" placeholder="${window.siyuan.languages.twoFactorCaptcha}">
        </div>
        <div class="fn__hr--b"></div>
        <button id="login2" class="b3-button fn__block">${window.siyuan.languages.login}</button>
    </div>
</div>
<div class="config-account__center config-account__center--text${window.siyuan.config.system.container === "ios" ? " fn__none" : ""}">
    <div class="fn__flex-1 fn__hr--b"></div>
    ${genSVGBG()}
    <div class="fn__flex-1 fn__hr--b"></div>    
    ${payHTML}
    <div class="fn__flex-1 fn__hr--b"></div>
    ${genSVGBG()}
    <div class="fn__flex-1 fn__hr--b"></div>
</div>
</div>`;
    },
    bindEvent: (element: Element) => {
        element.querySelectorAll('[data-action="iOSPay"]').forEach(item => {
            item.addEventListener("click", () => {
                iOSPurchase(item.getAttribute("data-type"));
            });
        });
        const trialSubElement = element.querySelector("#trialSub");
        if (trialSubElement) {
            trialSubElement.addEventListener("click", () => {
                fetchPost("/api/account/startFreeTrial", {}, () => {
                    element.querySelector("#refresh").dispatchEvent(new Event("click"));
                });
            });
        }
        const userNameElement = element.querySelector("#userName") as HTMLInputElement;
        if (!userNameElement) {
            const refreshElement = element.querySelector("#refresh");
            refreshElement.addEventListener("click", () => {
                const svgElement = refreshElement.firstElementChild;
                if (svgElement.classList.contains("fn__rotate")) {
                    return;
                }
                svgElement.classList.add("fn__rotate");
                fetchPost("/api/setting/getCloudUser", {
                    token: window.siyuan.user.userToken,
                }, response => {
                    window.siyuan.user = response.data;
                    element.innerHTML = account.genHTML();
                    account.bindEvent(element);
                    showMessage(window.siyuan.languages.refreshUser, 3000);
                    account.onSetaccount();
                    processSync();
                });
            });
            element.querySelector("#logout").addEventListener("click", () => {
                fetchPost("/api/setting/logoutCloudUser", {}, () => {
                    fetchPost("/api/setting/getCloudUser", {}, response => {
                        window.siyuan.user = response.data;
                        element.innerHTML = account.genHTML();
                        account.bindEvent(element);
                        account.onSetaccount();
                        processSync();
                    });
                });
            });
            element.querySelector("#deactivateUser").addEventListener(getEventName(), () => {
                confirmDialog("⚠️ " + window.siyuan.languages.deactivateUser, window.siyuan.languages.deactivateUserTip, () => {
                    fetchPost("/api/account/deactivate", {}, () => {
                        window.siyuan.user = null;
                        element.innerHTML = account.genHTML();
                        account.bindEvent(element);
                        account.onSetaccount();
                        processSync();
                    });
                });
            });
            element.querySelectorAll("input[type='checkbox']").forEach(item => {
                item.addEventListener("change", () => {
                    fetchPost("/api/setting/setAccount", {
                        displayTitle: (element.querySelector("#displayTitle") as HTMLInputElement).checked,
                        displayVIP: (element.querySelector("#displayVIP") as HTMLInputElement).checked,
                    }, (response) => {
                        window.siyuan.config.account.displayTitle = response.data.displayTitle;
                        window.siyuan.config.account.displayVIP = response.data.displayVIP;
                        account.onSetaccount();
                    });
                });
            });
            const activationCodeElement = element.querySelector("#activationCode");
            activationCodeElement?.addEventListener("click", () => {
                const activationCodeInput = (activationCodeElement.previousElementSibling as HTMLInputElement);
                fetchPost("/api/account/checkActivationcode", {data: activationCodeInput.value}, (response) => {
                    if (0 !== response.code) {
                        activationCodeInput.value = "";
                    }
                    confirmDialog(window.siyuan.languages.activationCode, response.msg, () => {
                        if (response.code === 0) {
                            fetchPost("/api/account/useActivationcode", {data: (activationCodeElement.previousElementSibling as HTMLInputElement).value}, () => {
                                refreshElement.dispatchEvent(new CustomEvent("click"));
                            });
                        }
                    });
                });
            });
            return;
        }

        const userPasswordElement = element.querySelector("#userPassword") as HTMLInputElement;
        const captchaImgElement = element.querySelector("#captchaImg") as HTMLInputElement;
        const captchaElement = element.querySelector("#captcha") as HTMLInputElement;
        const twofactorAuthCodeElement = element.querySelector("#twofactorAuthCode") as HTMLInputElement;
        const loginBtnElement = element.querySelector("#login") as HTMLButtonElement;
        const login2BtnElement = element.querySelector("#login2") as HTMLButtonElement;
        userNameElement.focus();
        userNameElement.addEventListener("keydown", (event) => {
            if (event.isComposing) {
                event.preventDefault();
                return;
            }
            if (event.key === "Enter") {
                loginBtnElement.click();
                event.preventDefault();
            }
        });

        twofactorAuthCodeElement.addEventListener("keydown", (event) => {
            if (event.isComposing) {
                event.preventDefault();
                return;
            }
            if (event.key === "Enter") {
                login2BtnElement.click();
                event.preventDefault();
            }
        });

        captchaElement.addEventListener("keydown", (event) => {
            if (event.isComposing) {
                event.preventDefault();
                return;
            }
            if (event.key === "Enter") {
                loginBtnElement.click();
                event.preventDefault();
            }
        });
        userPasswordElement.addEventListener("keydown", (event) => {
            if (event.isComposing) {
                event.preventDefault();
                return;
            }
            if (event.key === "Enter") {
                loginBtnElement.click();
                event.preventDefault();
            }
        });
        let token: string;
        let needCaptcha: string;
        captchaImgElement.addEventListener("click", () => {
            captchaImgElement.setAttribute("src", getCloudURL("captcha") + `/login?needCaptcha=${needCaptcha}&t=${new Date().getTime()}`);
        });

        loginBtnElement.addEventListener("click", () => {
            fetchPost("/api/account/login", {
                userName: userNameElement.value.replace(/(^\s*)|(\s*$)/g, ""),
                userPassword: md5(userPasswordElement.value),
                captcha: captchaElement.value.replace(/(^\s*)|(\s*$)/g, ""),
            }, (data) => {
                let messageId;
                if (data.code === 1) {
                    messageId = showMessage(data.msg);
                    if (data.data.needCaptcha) {
                        // 验证码
                        needCaptcha = data.data.needCaptcha;
                        captchaElement.parentElement.classList.remove("fn__none");
                        captchaElement.previousElementSibling.setAttribute("src",
                            getCloudURL("captcha") + `/login?needCaptcha=${data.data.needCaptcha}`);
                        captchaElement.value = "";
                        return;
                    }
                    return;
                }
                if (data.code === 10) {
                    // 两步验证
                    element.querySelector("#form1").classList.add("fn__none");
                    element.querySelector("#form2").classList.remove("fn__none");
                    twofactorAuthCodeElement.focus();
                    token = data.data.token;
                    return;
                }
                hideMessage(messageId);
                fetchPost("/api/setting/getCloudUser", {
                    token: data.data.token,
                }, response => {
                    account._afterLogin(response, element);
                });
            });
        });

        login2BtnElement.addEventListener("click", () => {
            fetchPost("/api/setting/login2faCloudUser", {
                code: twofactorAuthCodeElement.value,
                token,
            }, response => {
                fetchPost("/api/setting/getCloudUser", {
                    token: response.data.token,
                }, userResponse => {
                    account._afterLogin(userResponse, element);
                });
            });
        });
    },
    _afterLogin(userResponse: IWebSocketData, element: Element) {
        window.siyuan.user = userResponse.data;
        processSync();
        element.innerHTML = account.genHTML();
        account.bindEvent(element);
        account.onSetaccount();
        if (element.getAttribute("data-action") === "go-repos") {
            if (needSubscribe("") && 0 === window.siyuan.config.sync.provider) {
                const dialogElement = hasClosestByClassName(element, "b3-dialog--open");
                if (dialogElement) {
                    dialogElement.querySelector('.b3-tab-bar [data-name="repos"]').dispatchEvent(new CustomEvent("click"));
                    element.removeAttribute("data-action");
                }
            } else {
                hideElements(["dialog"]);
                syncGuide();
            }
        }
    },
    onSetaccount() {
        if (repos.element) {
            repos.element.innerHTML = "";
        }
        if (window.siyuan.config.system.container === "ios") {
            return;
        }
        let html = "";
        if (window.siyuan.config.account.displayVIP) {
            if (window.siyuan.user) {
                if (window.siyuan.user.userSiYuanProExpireTime === -1) { // 终身会员
                    html = `<div class="toolbar__item ariaLabel" aria-label="${window.siyuan.languages.account12}">${Constants.SIYUAN_IMAGE_VIP}</div>`;
                } else if (window.siyuan.user.userSiYuanProExpireTime > 0) { // 订阅中
                    if (window.siyuan.user.userSiYuanSubscriptionPlan === 2) { // 试用订阅
                        html = `<div class="toolbar__item ariaLabel" aria-label="${window.siyuan.languages.account3}"><svg><use xlink:href="#iconVIP"></use></svg></div>`;
                    } else { // 正常订阅
                        html = `<div class="toolbar__item ariaLabel" aria-label="${window.siyuan.languages.account10}"><svg class="ft__secondary"><use xlink:href="#iconVIP"></use></svg></div>`;
                    }
                } else if (window.siyuan.user.userSiYuanSubscriptionStatus === -1) { // 未订阅
                    html = `<div class="toolbar__item ariaLabel" aria-label="${window.siyuan.languages.freeSub}"><svg class="ft__error"><use xlink:href="#iconVIP"></use></svg></div>`;
                }
                if (window.siyuan.user.userSiYuanOneTimePayStatus === 1) { // 一次性付费功能特性
                    html += `<div class="toolbar__item ariaLabel" aria-label="${window.siyuan.languages.onepay}"><svg class="ft__success"><use xlink:href="#iconVIP"></use></svg></div>`;
                }
            } else { // 未登录
                html = `<div class="toolbar__item ariaLabel" aria-label="${window.siyuan.languages.freeSub}"><svg class="ft__error"><use xlink:href="#iconVIP"></use></svg></div>`;
            }
        }
        if (window.siyuan.config.account.displayTitle && window.siyuan.user) {
            window.siyuan.user.userTitles.forEach(item => {
                html += `<div class="toolbar__item ariaLabel" aria-label="${item.name}：${item.desc}">${item.icon}</div>`;
            });
        }
        document.getElementById("toolbarVIP").innerHTML = html;
    }
};
