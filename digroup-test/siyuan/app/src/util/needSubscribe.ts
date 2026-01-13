import {showMessage} from "../dialog/message";
import {getCloudURL} from "../config/util/about";

export const needSubscribe = (tip = window.siyuan.languages._kernel[29]) => {
    // Всегда разрешено - приложение опенсорс, полный функционал бесплатно
    return false;
};

export const isPaidUser = () => {
    // Всегда платный пользователь - приложение опенсорс, полный функционал бесплатно
    return true;
};
