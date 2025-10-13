(globalThis.TURBOPACK || (globalThis.TURBOPACK = [])).push([typeof document === "object" ? document.currentScript : undefined,
"[project]/app/(features)/products/_components/product-card.tsx [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "ProductCard",
    ()=>ProductCard
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/next/dist/compiled/react/jsx-dev-runtime.js [app-client] (ecmascript)");
'use client';
;
function ProductCard(param) {
    let { product } = param;
    return /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("article", {
        className: "rounded-md border border-gray-200 p-4 shadow-sm",
        children: [
            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("h2", {
                className: "text-lg font-semibold",
                children: product.name
            }, void 0, false, {
                fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                lineNumber: 12,
                columnNumber: 7
            }, this),
            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("dl", {
                className: "mt-2 space-y-1 text-sm",
                children: [
                    /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("div", {
                        className: "flex justify-between",
                        children: [
                            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("dt", {
                                className: "font-medium text-gray-500",
                                children: "Giá"
                            }, void 0, false, {
                                fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                                lineNumber: 15,
                                columnNumber: 11
                            }, this),
                            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("dd", {
                                className: "font-semibold text-gray-900",
                                children: product.price.toLocaleString('vi-VN', {
                                    style: 'currency',
                                    currency: 'VND'
                                })
                            }, void 0, false, {
                                fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                                lineNumber: 16,
                                columnNumber: 11
                            }, this)
                        ]
                    }, void 0, true, {
                        fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                        lineNumber: 14,
                        columnNumber: 9
                    }, this),
                    /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("div", {
                        className: "flex justify-between text-gray-600",
                        children: [
                            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("dt", {
                                children: "Mã"
                            }, void 0, false, {
                                fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                                lineNumber: 21,
                                columnNumber: 11
                            }, this),
                            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("dd", {
                                children: product.id
                            }, void 0, false, {
                                fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                                lineNumber: 22,
                                columnNumber: 11
                            }, this)
                        ]
                    }, void 0, true, {
                        fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                        lineNumber: 20,
                        columnNumber: 9
                    }, this)
                ]
            }, void 0, true, {
                fileName: "[project]/app/(features)/products/_components/product-card.tsx",
                lineNumber: 13,
                columnNumber: 7
            }, this)
        ]
    }, void 0, true, {
        fileName: "[project]/app/(features)/products/_components/product-card.tsx",
        lineNumber: 11,
        columnNumber: 5
    }, this);
}
_c = ProductCard;
var _c;
__turbopack_context__.k.register(_c, "ProductCard");
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/lib/supabase/client.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "supabaseClient",
    ()=>supabaseClient
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = /*#__PURE__*/ __turbopack_context__.i("[project]/node_modules/next/dist/build/polyfills/process.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$supabase$2f$supabase$2d$js$2f$dist$2f$module$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/node_modules/@supabase/supabase-js/dist/module/index.js [app-client] (ecmascript) <locals>");
;
const supabaseUrl = ("TURBOPACK compile-time value", "https://paidjvxqwjhrlhlhfetjqv.supabase.co");
const supabaseAnonKey = ("TURBOPACK compile-time value", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhaWRqdnhxd2hybGhsZmV0anF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyMDA3NzQsImV4cCI6MjA3Mzc3Njc3NH0.T2tmN-D-Y1kJre4Ys-McsKW46615mqEcTgIIz-_yaDA");
if ("TURBOPACK compile-time falsy", 0) //TURBOPACK unreachable
;
const supabaseClient = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$supabase$2f$supabase$2d$js$2f$dist$2f$module$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__$3c$locals$3e$__["createClient"])(supabaseUrl, supabaseAnonKey);
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/lib/api/utils.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "getAuthHeaders",
    ()=>getAuthHeaders
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$supabase$2f$client$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/supabase/client.ts [app-client] (ecmascript)");
;
async function getAuthHeaders() {
    const { data: { session }, error } = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$supabase$2f$client$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["supabaseClient"].auth.getSession();
    if (error) {
        throw error;
    }
    if (!session) {
        throw new Error('User not logged in. Vui lòng đăng nhập trước khi truy cập dữ liệu được bảo vệ.');
    }
    return {
        Authorization: "Bearer ".concat(session.access_token),
        'Content-Type': 'application/json'
    };
}
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/lib/api/products.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "productService",
    ()=>productService
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/api/utils.ts [app-client] (ecmascript)");
;
const productService = {
    getPaginated: async function() {
        let params = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {};
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams();
        if (params.category) {
            searchParams.set('category', params.category);
        }
        if (params.companyId) {
            searchParams.set('companyId', params.companyId);
        }
        if (typeof params.limit === 'number') {
            searchParams.set('limit', params.limit.toString());
        }
        if (typeof params.offset === 'number') {
            searchParams.set('offset', params.offset.toString());
        }
        if (params.sortBy) {
            searchParams.set('sortBy', params.sortBy);
        }
        if (typeof params.ascending === 'boolean') {
            searchParams.set('ascending', String(params.ascending));
        }
        const response = await fetch("/api/products?".concat(searchParams.toString()), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch products');
        }
        const payload = await response.json();
        var _payload_limit, _ref;
        const limitValue = (_ref = (_payload_limit = payload.limit) !== null && _payload_limit !== void 0 ? _payload_limit : params === null || params === void 0 ? void 0 : params.limit) !== null && _ref !== void 0 ? _ref : 50;
        var _payload_offset, _ref1;
        const offsetValue = (_ref1 = (_payload_offset = payload.offset) !== null && _payload_offset !== void 0 ? _payload_offset : params === null || params === void 0 ? void 0 : params.offset) !== null && _ref1 !== void 0 ? _ref1 : 0;
        var _payload_totalCount, _ref2;
        const total = (_ref2 = (_payload_totalCount = payload.totalCount) !== null && _payload_totalCount !== void 0 ? _payload_totalCount : payload.total) !== null && _ref2 !== void 0 ? _ref2 : 0;
        var _payload_items, _payload_hasNextPage;
        return {
            items: (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [],
            totalCount: total,
            offset: offsetValue,
            limit: limitValue,
            hasNextPage: (_payload_hasNextPage = payload.hasNextPage) !== null && _payload_hasNextPage !== void 0 ? _payload_hasNextPage : offsetValue + limitValue < total
        };
    },
    getAll: async ()=>{
        const items = [];
        let offset = 0;
        const limit = 100;
        while(true){
            const result = await productService.getPaginated({
                limit,
                offset
            });
            items.push(...result.items);
            if (!result.hasNextPage) {
                break;
            }
            const nextOffset = result.offset + result.limit;
            if (nextOffset <= offset) {
                break;
            }
            offset = nextOffset;
        }
        return items;
    },
    getByCompany: async (companyId)=>{
        if (!companyId) {
            return productService.getAll();
        }
        const items = [];
        let offset = 0;
        const limit = 100;
        while(true){
            const result = await productService.getPaginated({
                companyId,
                limit,
                offset
            });
            items.push(...result.items);
            if (!result.hasNextPage) {
                break;
            }
            const nextOffset = result.offset + result.limit;
            if (nextOffset <= offset) {
                break;
            }
            offset = nextOffset;
        }
        return items;
    },
    getById: async (id)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(id), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch product');
        }
        return response.json();
    },
    searchPaginated: async (params)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams({
            q: params.query
        });
        if (params.category) {
            searchParams.set('category', params.category);
        }
        if (typeof params.minPrice === 'number') {
            searchParams.set('minPrice', params.minPrice.toString());
        }
        if (typeof params.maxPrice === 'number') {
            searchParams.set('maxPrice', params.maxPrice.toString());
        }
        if (typeof params.inStock === 'boolean') {
            searchParams.set('inStock', String(params.inStock));
        }
        if (typeof params.limit === 'number') {
            searchParams.set('limit', params.limit.toString());
        }
        if (typeof params.offset === 'number') {
            searchParams.set('offset', params.offset.toString());
        }
        const response = await fetch("/api/products/search?".concat(searchParams.toString()), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to search products');
        }
        const payload = await response.json();
        var _payload_limit, _ref;
        const limitValue = (_ref = (_payload_limit = payload.limit) !== null && _payload_limit !== void 0 ? _payload_limit : params === null || params === void 0 ? void 0 : params.limit) !== null && _ref !== void 0 ? _ref : 50;
        var _payload_offset, _ref1;
        const offsetValue = (_ref1 = (_payload_offset = payload.offset) !== null && _payload_offset !== void 0 ? _payload_offset : params === null || params === void 0 ? void 0 : params.offset) !== null && _ref1 !== void 0 ? _ref1 : 0;
        var _payload_totalCount, _ref2;
        const total = (_ref2 = (_payload_totalCount = payload.totalCount) !== null && _payload_totalCount !== void 0 ? _payload_totalCount : payload.total) !== null && _ref2 !== void 0 ? _ref2 : 0;
        var _payload_items, _payload_hasNextPage;
        return {
            items: (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [],
            totalCount: total,
            offset: offsetValue,
            limit: limitValue,
            hasNextPage: (_payload_hasNextPage = payload.hasNextPage) !== null && _payload_hasNextPage !== void 0 ? _payload_hasNextPage : offsetValue + limitValue < total
        };
    },
    search: async (query)=>{
        const result = await productService.searchPaginated({
            query,
            limit: 50
        });
        return result.items;
    },
    getBatchesPaginated: async (productId, params)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams();
        if (params === null || params === void 0 ? void 0 : params.limit) {
            searchParams.set('limit', params.limit.toString());
        }
        if (params === null || params === void 0 ? void 0 : params.offset) {
            searchParams.set('offset', params.offset.toString());
        }
        const queryString = searchParams.toString();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/batches").concat(queryString ? "?".concat(queryString) : ''), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch product batches');
        }
        const payload = await response.json();
        var _payload_limit, _ref;
        const limitValue = (_ref = (_payload_limit = payload.limit) !== null && _payload_limit !== void 0 ? _payload_limit : params.limit) !== null && _ref !== void 0 ? _ref : 50;
        var _payload_offset, _ref1;
        const offsetValue = (_ref1 = (_payload_offset = payload.offset) !== null && _payload_offset !== void 0 ? _payload_offset : params.offset) !== null && _ref1 !== void 0 ? _ref1 : 0;
        var _payload_items, _payload_totalCount, _ref2, _payload_totalCount1, _ref3, _payload_hasNextPage;
        return {
            items: (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [],
            totalCount: (_ref2 = (_payload_totalCount = payload.totalCount) !== null && _payload_totalCount !== void 0 ? _payload_totalCount : payload.total) !== null && _ref2 !== void 0 ? _ref2 : 0,
            offset: offsetValue,
            limit: limitValue,
            hasNextPage: (_payload_hasNextPage = payload.hasNextPage) !== null && _payload_hasNextPage !== void 0 ? _payload_hasNextPage : ((_ref3 = (_payload_totalCount1 = payload.totalCount) !== null && _payload_totalCount1 !== void 0 ? _payload_totalCount1 : payload.total) !== null && _ref3 !== void 0 ? _ref3 : 0) > offsetValue + limitValue
        };
    },
    getBatches: async (productId)=>{
        const pageSize = 100;
        let offset = 0;
        const items = [];
        // Loop until no more pages
        while(true){
            const result = await productService.getBatchesPaginated(productId, {
                limit: pageSize,
                offset
            });
            items.push(...result.items);
            if (!result.hasNextPage) {
                break;
            }
            const nextOffset = result.offset + result.limit;
            // Prevent infinite loops by ensuring offset increases
            if (nextOffset <= offset) {
                break;
            }
            offset = nextOffset;
        }
        return items;
    },
    getProductUnits: async (productId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/rpc/get_product_units', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                p_product_id: productId
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch product units');
        }
        const payload = await response.json();
        return Array.isArray(payload) ? payload : [];
    },
    getDefaultUnit: async (productId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/units/default"), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch default unit');
        }
        const payload = await response.json();
        var _ref;
        return (_ref = payload.item) !== null && _ref !== void 0 ? _ref : null;
    },
    createProductUnit: async (productId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/units"), {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            const message = (_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to create product unit';
            if (message.includes('product_units_unique_name_per_product')) {
                throw new Error('Đơn vị đã tồn tại cho sản phẩm này');
            }
            throw new Error(message);
        }
        return response.json();
    },
    updateProductUnit: async (unitId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/product-units/".concat(encodeURIComponent(unitId)), {
            method: 'PATCH',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to update product unit');
        }
        return response.json();
    },
    deleteProductUnit: async (unitId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/product-units/".concat(encodeURIComponent(unitId)), {
            method: 'DELETE',
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to delete product unit');
        }
    },
    setDefaultUnit: async (productId, unitId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/units/").concat(encodeURIComponent(unitId)), {
            method: 'POST',
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to set default unit');
        }
        return response.json();
    },
    checkStockAvailability: async (productId, quantity, unitId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/rpc/check_stock_availability', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                p_product_id: productId,
                p_quantity: quantity,
                p_unit_id: unitId
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to check stock availability');
        }
        const payload = await response.json();
        return Boolean(payload);
    },
    getAvailableStockBaseUnit: async (productId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/rpc/get_available_stock_base_unit', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                p_product_id: productId
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to get available stock base unit');
        }
        const payload = await response.json();
        return typeof payload === 'number' ? payload : Number(payload !== null && payload !== void 0 ? payload : 0);
    },
    addBatch: async (productId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/batches"), {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to add product batch');
        }
        return response.json();
    },
    updateBatch: async (productId, batchId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/batches/").concat(encodeURIComponent(batchId)), {
            method: 'PATCH',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to update product batch');
        }
        return response.json();
    },
    deleteBatch: async (batchId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/product-batches/".concat(encodeURIComponent(batchId)), {
            method: 'DELETE',
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to delete product batch');
        }
    },
    getAvailableStock: async (productId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/stock"), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to get available stock');
        }
        const payload = await response.json();
        var _payload_stock;
        return (_payload_stock = payload.stock) !== null && _payload_stock !== void 0 ? _payload_stock : 0;
    },
    getExpiringBatches: async (months)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams();
        if (months && months > 0) {
            searchParams.set('months', months.toString());
        }
        const queryString = searchParams.toString();
        const response = await fetch("/api/inventory/expiring-batches".concat(queryString ? "?".concat(queryString) : ''), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch expiring batches');
        }
        const payload = await response.json();
        var _payload_items;
        return (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [];
    },
    getLowStockProducts: async ()=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/inventory/low-stock', {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch low stock products');
        }
        const payload = await response.json();
        var _payload_items;
        return (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [];
    },
    quickAddBatch: async (productId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/quick-add-batch"), {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to quick add batch');
        }
        const updatedProduct = await response.json();
        return updatedProduct;
    },
    quickSearchForPOS: async (query)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams({
            q: query
        });
        const response = await fetch("/api/products/pos-search?".concat(searchParams.toString()), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to search products for POS');
        }
        const payload = await response.json();
        var _payload_items;
        return (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [];
    },
    scanBySKU: async (sku)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams({
            sku
        });
        const response = await fetch("/api/products/scan?".concat(searchParams.toString()), {
            headers
        });
        if (response.status === 404) {
            return null;
        }
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to scan product by SKU');
        }
        const payload = await response.json();
        var _payload_item;
        return (_payload_item = payload.item) !== null && _payload_item !== void 0 ? _payload_item : null;
    },
    create: async (payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/products', {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to create product');
        }
        return response.json();
    },
    update: async (id, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(id)), {
            method: 'PUT',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to update product');
        }
        return response.json();
    },
    delete: async (id)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(id)), {
            method: 'DELETE',
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to delete product');
        }
    },
    getCurrentPrice: async (id)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(id), "/current-price"), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to get current price');
        }
        const payload = await response.json();
        var _payload_price;
        return (_payload_price = payload.price) !== null && _payload_price !== void 0 ? _payload_price : 0;
    },
    updateCurrentSellingPrice: async (id, newPrice, reason)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(id), "/current-price"), {
            method: 'PATCH',
            headers,
            body: JSON.stringify({
                newPrice,
                reason
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to update product price');
        }
        const payload = await response.json().catch(()=>({}));
        return (payload === null || payload === void 0 ? void 0 : payload.success) !== false;
    },
    calculateAverageCostPrice: async (id)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/rpc/get_average_cost_price', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                p_product_id: id
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to calculate average cost price');
        }
        const value = await response.json();
        return value !== null && value !== void 0 ? value : 0;
    },
    calculateGrossProfitPercentage: async (id)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/rpc/get_gross_profit_percentage', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                p_product_id: id
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to calculate gross profit percentage');
        }
        const value = await response.json();
        return value !== null && value !== void 0 ? value : 0;
    },
    getPriceHistory: async function(id) {
        let limit = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : 20;
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const searchParams = new URLSearchParams({
            limit: String(limit)
        });
        const response = await fetch("/api/products/".concat(encodeURIComponent(id), "/price-history?").concat(searchParams.toString()), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch price history');
        }
        const payload = await response.json();
        var _payload_items;
        return (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [];
    },
    getSeasonalPrices: async (productId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/seasonal-prices"), {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch seasonal prices');
        }
        const payload = await response.json();
        var _payload_items;
        return (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [];
    },
    addSeasonalPrice: async (productId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/seasonal-prices"), {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to add seasonal price');
        }
        return response.json();
    },
    updateSeasonalPrice: async (productId, priceId, payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/seasonal-prices/").concat(encodeURIComponent(priceId)), {
            method: 'PATCH',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to update seasonal price');
        }
        return response.json();
    },
    deleteSeasonalPrice: async (productId, priceId)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch("/api/products/".concat(encodeURIComponent(productId), "/seasonal-prices/").concat(encodeURIComponent(priceId)), {
            method: 'DELETE',
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to delete seasonal price');
        }
    },
    getBannedSubstances: async ()=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/banned-substances', {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch banned substances');
        }
        const payload = await response.json();
        var _payload_items;
        return (_payload_items = payload.items) !== null && _payload_items !== void 0 ? _payload_items : [];
    },
    addBannedSubstance: async (payload)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/banned-substances', {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to add banned substance');
        }
        return response.json();
    },
    checkBannedSubstance: async (activeIngredient)=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/banned-substances/check', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                activeIngredient
            })
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to check banned substance');
        }
        const payload = await response.json();
        return Boolean(payload.isBanned);
    },
    getProductDashboardStats: async ()=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/products/dashboard', {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch product dashboard stats');
        }
        return response.json();
    },
    getTotalProductsCount: async ()=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/products/count', {
            headers
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to fetch product count');
        }
        const payload = await response.json();
        var _payload_total, _ref;
        return (_ref = (_payload_total = payload.total) !== null && _payload_total !== void 0 ? _payload_total : payload.totalCount) !== null && _ref !== void 0 ? _ref : 0;
    },
    refreshMaterializedViews: async ()=>{
        const headers = await (0, __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$utils$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuthHeaders"])();
        const response = await fetch('/api/rpc/refresh_materialized_views', {
            method: 'POST',
            headers,
            body: JSON.stringify({})
        });
        if (!response.ok) {
            const errorData = await response.json().catch(()=>({}));
            var _errorData_error;
            throw new Error((_errorData_error = errorData.error) !== null && _errorData_error !== void 0 ? _errorData_error : 'Failed to refresh materialized views');
        }
    }
};
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/lib/cache/memory-cache.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "MemoryCache",
    ()=>MemoryCache,
    "memoryCache",
    ()=>memoryCache
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$swc$2f$helpers$2f$esm$2f$_define_property$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/@swc/helpers/esm/_define_property.js [app-client] (ecmascript)");
;
class MemoryCache {
    get(key) {
        const entry = this.store.get(key);
        if (!entry) {
            return null;
        }
        if (!entry.persistent && entry.expiresAt < Date.now()) {
            this.store.delete(key);
            return null;
        }
        return entry.value;
    }
    set(key, value, ttlMs) {
        let persistent = arguments.length > 3 && arguments[3] !== void 0 ? arguments[3] : false;
        const expiresAt = persistent ? Number.POSITIVE_INFINITY : Date.now() + ttlMs;
        this.store.set(key, {
            value,
            expiresAt,
            persistent
        });
    }
    invalidate(key) {
        this.store.delete(key);
    }
    invalidateWhere(predicate) {
        for (const key of this.store.keys()){
            if (predicate(key)) {
                this.store.delete(key);
            }
        }
    }
    clear() {
        this.store.clear();
    }
    constructor(){
        (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f40$swc$2f$helpers$2f$esm$2f$_define_property$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["_"])(this, "store", new Map());
    }
}
const memoryCache = new MemoryCache();
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/lib/cache/cached-products.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "cachedProductService",
    ()=>cachedProductService
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/api/products.ts [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/cache/memory-cache.ts [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$supabase$2f$client$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/supabase/client.ts [app-client] (ecmascript)");
;
;
;
const DEFAULT_PAGINATED_TTL_MS = 3 * 60 * 1000; // 3 minutes
const DEFAULT_SEARCH_TTL_MS = 2 * 60 * 1000; // 2 minutes
const DEFAULT_DASHBOARD_TTL_MS = 10 * 60 * 1000; // 10 minutes
const DEFAULT_LOW_STOCK_TTL_MS = 5 * 60 * 1000; // 5 minutes
let cachedStoreId = null;
async function getStoreKey() {
    var _session_user_user_metadata, _session_user;
    if (cachedStoreId) {
        return cachedStoreId;
    }
    const { data: { session } } = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$supabase$2f$client$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["supabaseClient"].auth.getSession();
    var _ref;
    cachedStoreId = (_ref = session === null || session === void 0 ? void 0 : (_session_user = session.user) === null || _session_user === void 0 ? void 0 : (_session_user_user_metadata = _session_user.user_metadata) === null || _session_user_user_metadata === void 0 ? void 0 : _session_user_user_metadata.store_id) !== null && _ref !== void 0 ? _ref : 'anonymous';
    return cachedStoreId;
}
function stableStringify(value) {
    const sortedEntries = Object.entries(value).filter((param)=>{
        let [, v] = param;
        return v !== undefined && v !== null;
    }).sort((param, param1)=>{
        let [a] = param, [b] = param1;
        return a < b ? -1 : a > b ? 1 : 0;
    });
    return JSON.stringify(sortedEntries);
}
async function buildKey(prefix, params) {
    const storeId = await getStoreKey();
    return "".concat(prefix, "::store=").concat(storeId, "::").concat(stableStringify(params));
}
function resetStoreKey() {
    cachedStoreId = null;
}
const cachedProductService = {
    async getPaginated () {
        let params = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {}, options = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {};
        var _options_useCache;
        const useCache = (_options_useCache = options.useCache) !== null && _options_useCache !== void 0 ? _options_useCache : true;
        var _options_ttlMs;
        const ttlMs = (_options_ttlMs = options.ttlMs) !== null && _options_ttlMs !== void 0 ? _options_ttlMs : DEFAULT_PAGINATED_TTL_MS;
        const cacheKey = await buildKey('products:paginated', params);
        if (useCache) {
            const cached = __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].get(cacheKey);
            if (cached) {
                return cached;
            }
        }
        const result = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["productService"].getPaginated(params);
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].set(cacheKey, result, ttlMs);
        return result;
    },
    async getAll () {
        let options = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {};
        var _options_useCache;
        const useCache = (_options_useCache = options.useCache) !== null && _options_useCache !== void 0 ? _options_useCache : true;
        var _options_ttlMs;
        const ttlMs = (_options_ttlMs = options.ttlMs) !== null && _options_ttlMs !== void 0 ? _options_ttlMs : DEFAULT_PAGINATED_TTL_MS;
        const cacheKey = await buildKey('products:all', {});
        if (useCache) {
            const cached = __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].get(cacheKey);
            if (cached) {
                return cached;
            }
        }
        const result = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["productService"].getAll();
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].set(cacheKey, result, ttlMs);
        return result;
    },
    async search (query) {
        let params = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {}, options = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : {};
        const normalizedQuery = query.trim();
        if (normalizedQuery.length === 0) {
            var _params_offset, _params_limit;
            return {
                items: [],
                totalCount: 0,
                offset: (_params_offset = params.offset) !== null && _params_offset !== void 0 ? _params_offset : 0,
                limit: (_params_limit = params.limit) !== null && _params_limit !== void 0 ? _params_limit : 0,
                hasNextPage: false
            };
        }
        var _options_useCache;
        const useCache = (_options_useCache = options.useCache) !== null && _options_useCache !== void 0 ? _options_useCache : true;
        var _options_ttlMs;
        const ttlMs = (_options_ttlMs = options.ttlMs) !== null && _options_ttlMs !== void 0 ? _options_ttlMs : DEFAULT_SEARCH_TTL_MS;
        const cacheKey = await buildKey('products:search', {
            query: normalizedQuery.toLowerCase(),
            ...params
        });
        if (useCache) {
            const cached = __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].get(cacheKey);
            if (cached) {
                return cached;
            }
        }
        const result = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["productService"].searchPaginated({
            query: normalizedQuery,
            category: params.category,
            limit: params.limit,
            offset: params.offset
        });
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].set(cacheKey, result, ttlMs);
        return result;
    },
    async getDashboardStats () {
        let options = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {};
        var _options_useCache;
        const useCache = (_options_useCache = options.useCache) !== null && _options_useCache !== void 0 ? _options_useCache : true;
        var _options_ttlMs;
        const ttlMs = (_options_ttlMs = options.ttlMs) !== null && _options_ttlMs !== void 0 ? _options_ttlMs : DEFAULT_DASHBOARD_TTL_MS;
        const cacheKey = await buildKey('products:dashboard', {});
        if (useCache) {
            const cached = __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].get(cacheKey);
            if (cached) {
                return cached;
            }
        }
        const result = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["productService"].getProductDashboardStats();
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].set(cacheKey, result, ttlMs, true);
        return result;
    },
    async getLowStockProducts () {
        let options = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {};
        var _options_useCache;
        const useCache = (_options_useCache = options.useCache) !== null && _options_useCache !== void 0 ? _options_useCache : true;
        var _options_ttlMs;
        const ttlMs = (_options_ttlMs = options.ttlMs) !== null && _options_ttlMs !== void 0 ? _options_ttlMs : DEFAULT_LOW_STOCK_TTL_MS;
        const cacheKey = await buildKey('products:low-stock', {});
        if (useCache) {
            const cached = __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].get(cacheKey);
            if (cached) {
                return cached;
            }
        }
        const result = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["productService"].getLowStockProducts();
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].set(cacheKey, result, ttlMs);
        return result;
    },
    async refreshMaterializedViews () {
        await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$api$2f$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["productService"].refreshMaterializedViews();
        await this.invalidateProductCache();
        await this.invalidateDashboardCache();
    },
    async invalidateProductCache () {
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].invalidateWhere((key)=>key.startsWith('products:paginated') || key.startsWith('products:all'));
    },
    async invalidateSearchCache () {
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].invalidateWhere((key)=>key.startsWith('products:search'));
    },
    async invalidateDashboardCache () {
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].invalidateWhere((key)=>key.startsWith('products:dashboard') || key.startsWith('products:low-stock'));
    },
    clearAll () {
        resetStoreKey();
        __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$memory$2d$cache$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["memoryCache"].clear();
    }
};
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/hooks/use-products.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "useProducts",
    ()=>useProducts
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/next/dist/compiled/react/index.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$cached$2d$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/lib/cache/cached-products.ts [app-client] (ecmascript)");
var _s = __turbopack_context__.k.signature();
;
;
function useProducts() {
    _s();
    const [products, setProducts] = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useState"])([]);
    const [loading, setLoading] = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useState"])(true);
    const [error, setError] = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useState"])(null);
    const fetchProducts = (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useCallback"])({
        "useProducts.useCallback[fetchProducts]": async ()=>{
            try {
                setLoading(true);
                setError(null);
                const result = await __TURBOPACK__imported__module__$5b$project$5d2f$lib$2f$cache$2f$cached$2d$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["cachedProductService"].getPaginated({
                    limit: 100
                });
                setProducts(result.items);
            } catch (err) {
                const message = err instanceof Error ? err.message : 'Không thể tải sản phẩm';
                setError(message);
            } finally{
                setLoading(false);
            }
        }
    }["useProducts.useCallback[fetchProducts]"], []);
    (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useEffect"])({
        "useProducts.useEffect": ()=>{
            void fetchProducts();
        }
    }["useProducts.useEffect"], [
        fetchProducts
    ]);
    return {
        products,
        loading,
        error,
        refetch: fetchProducts
    };
}
_s(useProducts, "B0cKykw2W1YWdIApKYQsi4osLNc=");
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
"[project]/app/(features)/products/page.tsx [app-client] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "default",
    ()=>ProductsPage
]);
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/next/dist/compiled/react/jsx-dev-runtime.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$client$2f$app$2d$dir$2f$link$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/node_modules/next/dist/client/app-dir/link.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$app$2f28$features$292f$products$2f$_components$2f$product$2d$card$2e$tsx__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/app/(features)/products/_components/product-card.tsx [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$hooks$2f$use$2d$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/hooks/use-products.ts [app-client] (ecmascript)");
;
var _s = __turbopack_context__.k.signature();
'use client';
;
;
;
function ProductsPage() {
    _s();
    const { products, loading, error, refetch } = (0, __TURBOPACK__imported__module__$5b$project$5d2f$hooks$2f$use$2d$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useProducts"])();
    if (loading) {
        return /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("p", {
            children: "Đang tải danh sách sản phẩm..."
        }, void 0, false, {
            fileName: "[project]/app/(features)/products/page.tsx",
            lineNumber: 11,
            columnNumber: 12
        }, this);
    }
    if (error) {
        const requiresLogin = /đăng nhập/i.test(error);
        return /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("div", {
            className: "space-y-3",
            children: [
                /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("p", {
                    className: "text-red-500",
                    children: [
                        "Lỗi: ",
                        error
                    ]
                }, void 0, true, {
                    fileName: "[project]/app/(features)/products/page.tsx",
                    lineNumber: 18,
                    columnNumber: 9
                }, this),
                requiresLogin ? /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])(__TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$client$2f$app$2d$dir$2f$link$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"], {
                    href: "/auth/login?redirect=/products",
                    className: "inline-flex w-fit items-center justify-center rounded bg-green-600 px-4 py-2 text-white",
                    children: "Đăng nhập để tiếp tục"
                }, void 0, false, {
                    fileName: "[project]/app/(features)/products/page.tsx",
                    lineNumber: 20,
                    columnNumber: 11
                }, this) : /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("button", {
                    type: "button",
                    className: "rounded bg-blue-600 px-4 py-2 text-white",
                    onClick: refetch,
                    children: "Thử lại"
                }, void 0, false, {
                    fileName: "[project]/app/(features)/products/page.tsx",
                    lineNumber: 27,
                    columnNumber: 11
                }, this)
            ]
        }, void 0, true, {
            fileName: "[project]/app/(features)/products/page.tsx",
            lineNumber: 17,
            columnNumber: 7
        }, this);
    }
    return /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("section", {
        className: "space-y-6",
        children: [
            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("header", {
                className: "flex items-center justify-between",
                children: [
                    /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("div", {
                        children: [
                            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("h1", {
                                className: "text-2xl font-semibold",
                                children: "Sản phẩm"
                            }, void 0, false, {
                                fileName: "[project]/app/(features)/products/page.tsx",
                                lineNumber: 43,
                                columnNumber: 11
                            }, this),
                            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("p", {
                                className: "text-sm text-gray-600",
                                children: "Danh sách sản phẩm của cửa hàng bạn"
                            }, void 0, false, {
                                fileName: "[project]/app/(features)/products/page.tsx",
                                lineNumber: 44,
                                columnNumber: 11
                            }, this)
                        ]
                    }, void 0, true, {
                        fileName: "[project]/app/(features)/products/page.tsx",
                        lineNumber: 42,
                        columnNumber: 9
                    }, this),
                    /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])(__TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$client$2f$app$2d$dir$2f$link$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"], {
                        href: "/pos",
                        className: "rounded bg-green-600 px-4 py-2 text-white",
                        children: "Đi tới POS"
                    }, void 0, false, {
                        fileName: "[project]/app/(features)/products/page.tsx",
                        lineNumber: 46,
                        columnNumber: 9
                    }, this)
                ]
            }, void 0, true, {
                fileName: "[project]/app/(features)/products/page.tsx",
                lineNumber: 41,
                columnNumber: 7
            }, this),
            /*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])("div", {
                className: "grid gap-4 md:grid-cols-2 lg:grid-cols-3",
                children: products.map((product)=>/*#__PURE__*/ (0, __TURBOPACK__imported__module__$5b$project$5d2f$node_modules$2f$next$2f$dist$2f$compiled$2f$react$2f$jsx$2d$dev$2d$runtime$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["jsxDEV"])(__TURBOPACK__imported__module__$5b$project$5d2f$app$2f28$features$292f$products$2f$_components$2f$product$2d$card$2e$tsx__$5b$app$2d$client$5d$__$28$ecmascript$29$__["ProductCard"], {
                        product: product
                    }, product.id, false, {
                        fileName: "[project]/app/(features)/products/page.tsx",
                        lineNumber: 53,
                        columnNumber: 11
                    }, this))
            }, void 0, false, {
                fileName: "[project]/app/(features)/products/page.tsx",
                lineNumber: 51,
                columnNumber: 7
            }, this)
        ]
    }, void 0, true, {
        fileName: "[project]/app/(features)/products/page.tsx",
        lineNumber: 40,
        columnNumber: 5
    }, this);
}
_s(ProductsPage, "t1DVrcs/YDCSGcAHi4f0pd0BfAk=", false, function() {
    return [
        __TURBOPACK__imported__module__$5b$project$5d2f$hooks$2f$use$2d$products$2e$ts__$5b$app$2d$client$5d$__$28$ecmascript$29$__["useProducts"]
    ];
});
_c = ProductsPage;
var _c;
__turbopack_context__.k.register(_c, "ProductsPage");
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
]);

//# sourceMappingURL=_4c89d262._.js.map