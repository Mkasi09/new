"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { huaweiPushUrl } = require("../huawei_push");

test("Huawei Push Kit URL uses the v1 API and application ID", () => {
  assert.equal(
    huaweiPushUrl("118249943"),
    "https://push-api.cloud.huawei.com/v1/118249943/messages:send",
  );
});
