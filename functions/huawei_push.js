"use strict";

function huaweiPushUrl(appId) {
  return `https://push-api.cloud.huawei.com/v1/${encodeURIComponent(appId)}/messages:send`;
}

module.exports = { huaweiPushUrl };
