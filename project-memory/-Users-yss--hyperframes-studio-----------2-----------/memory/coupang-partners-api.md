---
name: coupang-partners-api
description: "Where the user's Coupang Partners API keys live and how calls are signed (product search, partner links)"
metadata:
  node_type: memory
  type: reference
  originSessionId: 3602d5e9-b847-4711-93ee-bd10978d38a1
  modified: 2026-10-09T06:20:51.002Z
---

Keys: `/Users/yss/개발/build/repick-cardnews/.env.local` → `COUPANG_ACCESS_KEY`, `COUPANG_SECRET_KEY`. Never print the values; read them in a script.

Signing (from that repo's `src/lib/coupang-best.ts`): host `https://api-gateway.coupang.com`, header `Authorization: CEA algorithm=HmacSHA256, access-key=…, signed-date=yyMMddTHHmmssZ (UTC), signature=hex(HMAC-SHA256(secret, signedDate + METHOD + path + query))`.

Tested 2026-10-09: `GET /v2/providers/affiliate_open_api/apis/openapi/products/search?keyword=<url-encoded>&limit=5` works and returns productName, productPrice, productImage, isRocket, productId and a partner tracking URL. It has no product detail text, so features still come from the main photo or a page screenshot. The response reminds that posts must carry the Partners disclosure (the Infork first line already does). Search calls are rate-limited, so one or two per product.

Use for the posting set in [[mompick-reel-workflow]]: match the user's product URL (productId in the URL) against search results, then use the name/price/image.

Learned 2026-10-09: search only returns top-ranked items, so a specific product link is often **not findable** (3 keyword searches missed productId 9695505620). Coupang product pages return 403 to curl, and the user rejected opening them in a headless browser — don't try that. If search misses, write from the video and ask the user for the product title. `POST /v2/providers/affiliate_open_api/apis/openapi/v1/deeplink` with body `{"coupangUrls":[url]}` (signature over signedDate+POST+path) works and returns the partner short link (`shortenUrl`, tag AF8564541) to put in the md for Infork. A link.coupang.com/a/… short link resolves to the product URL via one HTTP 302.
