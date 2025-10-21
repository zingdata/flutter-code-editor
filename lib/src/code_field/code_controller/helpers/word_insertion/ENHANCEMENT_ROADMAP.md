# SQL Editor Enhancement Roadmap

## Current State Assessment

### Overall Rating: **7.5/10** - Very Good SQL Editor

The current implementation is a **solid, production-ready SQL autocomplete system** with several world-class features. It compares favorably to basic SQL editors and covers the essential functionality needed for most SQL editing tasks.

### ✅ Strengths (Already World-Class)

| Feature | Implementation Quality | Industry Comparison |
|---------|----------------------|---------------------|
| **Multi-word Identifiers** | ⭐⭐⭐⭐⭐ Excellent | Matches DataGrip |
| **Quote Handling** (backticks, double quotes) | ⭐⭐⭐⭐ Very Good | Matches most editors |
| **SQL Aggregation Functions** | ⭐⭐⭐⭐⭐ Excellent | Auto-parentheses is rare |
| **Context Awareness** | ⭐⭐⭐⭐ Very Good | 9 SQL clauses detected |
| **Table→Column Flow** | ⭐⭐⭐⭐ Very Good | Matches DBeaver |
| **Token Matching** | ⭐⭐⭐⭐⭐ Excellent | 4 sophisticated patterns |
| **Cross-Platform** | ⭐⭐⭐⭐⭐ Excellent | Web + Mobile + Desktop |
| **Word Boundaries** | ⭐⭐⭐⭐ Very Good | Smart detection |
| **Test Coverage** | ⭐⭐⭐⭐⭐ Excellent | 68 comprehensive tests |

### What Users Will Love
- Seamless multi-word field completion ("order da" → "Order Date")
- Intelligent function parentheses insertion
- Fast, responsive suggestions across all platforms
- Robust handling of complex SQL identifiers
- Well-tested, reliable behavior

---

## Gap Analysis vs. World-Class SQL Editors

Comparison against **DataGrip**, **DBeaver**, **SQL Server Management Studio**, and **VS Code SQL Extensions**:

### ❌ Critical Missing Features

1. **Table Alias Support** ❌
   - Current: `SELECT users.id FROM users` ✅
   - Missing: `SELECT u.id FROM users u` ❌
   - Impact: **CRITICAL** - Used in 90% of production queries

2. **Single Quote Support** ❌
   - Current: Backticks `` `name` `` and double quotes `"name"` ✅
   - Missing: Single quotes `'name'` ❌
   - Impact: **CRITICAL** - MySQL/PostgreSQL standard

3. **Subquery Context** ❌
   - Current: Flat query structure ✅
   - Missing: Nested SELECT awareness ❌
   - Impact: **HIGH** - Common in complex queries

4. **JOIN ON Matching** ❌
   - Current: Manual column typing ✅
   - Missing: Smart column suggestions after ON ❌
   - Impact: **HIGH** - Major productivity boost

---

## Enhancement Plan

### 🎯 Priority 1: Critical for Professional Use

These features are **essential** for matching professional SQL editor expectations. Their absence is noticeable to experienced SQL developers.

#### 1. Table Alias Support

**Description:** Recognize and track table aliases to enable alias-prefixed column suggestions.

**Examples:**
```sql
-- Should work:
SELECT u.id, u.name FROM users u
SELECT c.name, o.total FROM customers c JOIN orders o ON c.id = o.customer_id
SELECT u.* FROM users u WHERE u.active = true
```

**Implementation Requirements:**
- Parse table aliases after FROM and JOIN clauses
- Track alias→table mapping in suggestion context
- Detect alias prefix before dot (e.g., `u.`)
- Filter column suggestions to show only columns from the aliased table
- Support multiple aliases simultaneously
- Handle alias in WHERE, GROUP BY, ORDER BY, HAVING clauses

**Test Coverage to Add:**
- Alias detection after FROM clause (3 tests)
- Alias detection after JOIN clauses (3 tests)
- Column suggestions with alias prefix (4 tests)
- Multi-table alias tracking (3 tests)
- Alias in WHERE/GROUP BY/ORDER BY (2 tests)

**Total: ~15 new tests**

**Complexity:** Medium

---

#### 2. Single Quote Support

**Description:** Add support for single-quoted identifiers and string literals, following SQL standard.

**Examples:**
```sql
-- Should work:
WHERE name = 'John'
SELECT 'Column Name' as col
INSERT INTO users ('First Name', 'Last Name') VALUES (...)
```

**Implementation Requirements:**
- Extend quote detection to include single quotes `'`
- Handle escape sequences (`''` for literal quote)
- Distinguish between identifier quotes and string literals based on context
- Update `stringWithoutQuotes` extension to handle all three quote types
- Support mixed quoting styles in same query

**Test Coverage to Add:**
- Single-quoted identifier detection (3 tests)
- Mixed quote styles (3 tests)
- Escape handling (2 tests)

**Total: ~8 new tests**

**Complexity:** Low-Medium

---

#### 3. Subquery Context Awareness

**Description:** Recognize subqueries and provide appropriate suggestions within nested SELECT statements.

**Examples:**
```sql
-- Should work:
SELECT * FROM (SELECT id, name FROM users) subq
SELECT u.name FROM (SELECT * FROM users WHERE active = true) u
WITH temp AS (SELECT id FROM users) SELECT * FROM temp
```

**Implementation Requirements:**
- Detect nested SELECT statements (parenthesized queries)
- Track nesting level and context
- Provide column suggestions based on subquery columns
- Support subquery aliases
- Handle multiple levels of nesting
- Integrate with CTE (WITH clause) detection

**Test Coverage to Add:**
- Nested SELECT detection (3 tests)
- Subquery alias handling (3 tests)
- Column suggestions within subqueries (3 tests)
- Multi-level nesting (3 tests)

**Total: ~12 new tests**

**Complexity:** High

---

#### 4. JOIN ON Column Matching

**Description:** Intelligently suggest matching columns when typing JOIN ON clauses.

**Examples:**
```sql
-- After typing "JOIN orders ON users."
-- Should suggest: id, customer_id, user_id (likely foreign keys)

JOIN orders o ON u.id = o.user_id
LEFT JOIN customers c ON o.customer_id = c.id
```

**Implementation Requirements:**
- Detect ON clause context
- Identify tables involved in the JOIN
- Suggest columns from appropriate table after dot
- Prioritize columns with similar names (foreign key patterns)
- Support multi-column JOIN conditions
- Handle table aliases in ON clause

**Test Coverage to Add:**
- ON clause detection (2 tests)
- Column suggestions after ON (3 tests)
- Foreign key pattern matching (3 tests)
- Alias support in ON clause (2 tests)

**Total: ~10 new tests**

**Complexity:** Medium

---

### ⭐ Priority 2: Nice-to-Have Professional Features

These features enhance the editor for **advanced use cases** but aren't critical for basic professional work.

#### 5. CTE (Common Table Expressions) Support

**Description:** Support WITH clause for temporary named result sets.

**Examples:**
```sql
WITH user_totals AS (
  SELECT user_id, SUM(amount) as total
  FROM orders
  GROUP BY user_id
)
SELECT u.name, ut.total
FROM users u
JOIN user_totals ut ON u.id = ut.user_id
```

**Implementation Requirements:**
- Detect WITH clause
- Track CTE names and their columns
- Treat CTEs as virtual tables for suggestions
- Support multiple CTEs in same query
- Handle recursive CTEs

**Test Coverage:** ~8 new tests

**Complexity:** Medium-High

---

#### 6. Schema-Qualified Names

**Description:** Support multi-level namespace qualification.

**Examples:**
```sql
SELECT database.schema.table.column
SELECT schema.table.column
SELECT public.users.name
```

**Implementation Requirements:**
- Parse dot-separated namespace hierarchies
- Track schema context
- Provide schema-aware suggestions
- Handle different database engines (PostgreSQL, SQL Server, etc.)

**Test Coverage:** ~10 new tests

**Complexity:** Medium

---

#### 7. Window Function Support

**Description:** Autocomplete for window functions with OVER clause.

**Examples:**
```sql
ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC)
SUM(amount) OVER (ORDER BY date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
```

**Implementation Requirements:**
- Detect window function context
- Suggest OVER clause after window functions
- Provide PARTITION BY and ORDER BY suggestions
- Support frame specifications (ROWS/RANGE)

**Test Coverage:** ~6 new tests

**Complexity:** Medium

---

#### 8. Function Parameter Hints

**Description:** Show parameter names and types after opening parenthesis.

**Examples:**
```sql
-- After typing "SUBSTRING("
-- Show: SUBSTRING(string, start [, length])

-- After typing "DATE_ADD("
-- Show: DATE_ADD(date, INTERVAL value unit)
```

**Implementation Requirements:**
- Define function signatures
- Detect function call context
- Display parameter hints in popup or tooltip
- Track current parameter position
- Support overloaded functions

**Test Coverage:** ~8 new tests

**Complexity:** Medium-High

---

### 🚀 Priority 3: Polish & Advanced Features

These are **future enhancements** for a truly best-in-class experience.

#### 9. SQL Dialect-Specific Support

**Description:** Tailor suggestions to specific SQL dialects.

**Dialects:**
- PostgreSQL (JSONB, arrays, specific functions)
- MySQL (specific syntax and functions)
- SQL Server (T-SQL specific features)
- SQLite (limited but specific feature set)

**Test Coverage:** ~20 new tests

**Complexity:** High

---

#### 10. Wildcard Column Expansion

**Description:** Expand `SELECT *` to actual column list.

**Example:**
```sql
-- Transform:
SELECT * FROM users

-- Into:
SELECT id, name, email, created_at FROM users
```

**Test Coverage:** ~5 new tests

**Complexity:** Low-Medium

---

#### 11. Error Recovery & Typo Correction

**Description:** Suggest corrections for common typos.

**Examples:**
- `SELCT` → Suggest `SELECT`
- `WERE` → Suggest `WHERE`
- `GROPU BY` → Suggest `GROUP BY`

**Test Coverage:** ~8 new tests

**Complexity:** Medium

---

#### 12. Template/Snippet Insertion

**Description:** Insert common SQL patterns quickly.

**Templates:**
```sql
-- CASE template
CASE
  WHEN condition THEN result
  ELSE default
END

-- JOIN template
LEFT JOIN table_name ON condition

-- Common aggregation
SELECT column, COUNT(*)
FROM table
GROUP BY column
```

**Test Coverage:** ~10 new tests

**Complexity:** Low

---

## Implementation Options

### Option A: Comprehensive Enhancement ⭐⭐⭐⭐⭐

**Scope:** All Priority 1 + Priority 2 features

**Includes:**
- ✅ Table aliases
- ✅ Single quotes
- ✅ Subqueries
- ✅ JOIN matching
- ✅ CTEs
- ✅ Schemas
- ✅ Window functions
- ✅ Parameter hints

**Test Coverage:** +71 new tests (total: ~139 tests)

**Time Estimate:** Significant development effort

**Result:** **9/10 rating** - On par with DataGrip/DBeaver

**Best For:** Building a premium SQL editing experience

---

### Option B: Critical Enhancement ⭐⭐⭐⭐ (RECOMMENDED)

**Scope:** Priority 1 only

**Includes:**
- ✅ Table aliases
- ✅ Single quotes
- ✅ Subqueries
- ✅ JOIN matching

**Test Coverage:** +45 new tests (total: ~113 tests)

**Time Estimate:** Moderate development effort

**Result:** **8.5/10 rating** - Strong professional SQL editor

**Best For:** Addressing the most noticeable gaps with reasonable effort

---

### Option C: Quick Win ⭐⭐⭐

**Scope:** Aliases + Single Quotes only

**Includes:**
- ✅ Table aliases
- ✅ Single quotes

**Test Coverage:** +23 new tests (total: ~91 tests)

**Time Estimate:** Minimal development effort

**Result:** **8/10 rating** - Addresses most common user complaints

**Best For:** Quick improvement with immediate user impact

---

## Recommendation: Option B

### Why Option B?

1. **Addresses Critical Gaps**
   - All four features are noticed by professional SQL developers
   - Missing features cause daily friction for users
   - Implements what 90% of users need

2. **Manageable Scope**
   - 45 tests is substantial but achievable
   - Features are relatively independent (can be implemented iteratively)
   - Clear success criteria for each feature

3. **Best ROI**
   - Biggest user satisfaction improvement per unit of effort
   - Moves from "good" to "professional-grade"
   - Positions package competitively against alternatives

4. **Foundation for Future**
   - Alias tracking enables CTE support later
   - Subquery detection enables recursive query handling
   - JOIN matching logic can extend to other clauses

---

## Comparison Matrix

### Current vs Enhanced vs Industry Leaders

| Feature Category | Current | After Option B | After Option A | DataGrip | DBeaver |
|-----------------|---------|----------------|----------------|----------|---------|
| Basic autocomplete | ✅ | ✅ | ✅ | ✅ | ✅ |
| Multi-word fields | ✅ | ✅ | ✅ | ✅ | ✅ |
| Table→Column | ✅ | ✅ | ✅ | ✅ | ✅ |
| SQL functions | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Table aliases** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Single quotes** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Subqueries** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **JOIN matching** | ❌ | ✅ | ✅ | ✅ | ✅ |
| CTEs | ❌ | ❌ | ✅ | ✅ | ✅ |
| Schemas | ❌ | ❌ | ✅ | ✅ | ✅ |
| Window functions | ❌ | ❌ | ✅ | ✅ | ✅ |
| Parameter hints | ❌ | ❌ | ✅ | ✅ | ✅ |
| SQL dialects | ❌ | ❌ | ❌ | ✅ | ✅ |
| Error recovery | ❌ | ❌ | ❌ | ✅ | ✅ |

---

## Implementation Guidelines

### Code Organization

Each new feature should follow the existing pattern:

1. **Feature Detection Logic**
   - Add detection methods in `SuggestionHelper`
   - Keep methods focused and testable

2. **Insertion Logic**
   - Extend `WordInsertionHelper` for replacement behavior
   - Maintain existing multi-word and quote handling patterns

3. **Test Coverage**
   - Create feature-specific test groups
   - Follow existing test structure (setUp, tearDown, clear test names)
   - Aim for 100% code coverage of new logic

4. **Documentation**
   - Update WORD_INSERTION.md with new examples
   - Document edge cases and limitations
   - Add integration notes for consumers

### Testing Strategy

For each new feature:

1. **Unit Tests** - Test detection logic in isolation
2. **Integration Tests** - Test full insertion flow
3. **Edge Case Tests** - Cover unusual inputs and SQL patterns
4. **Performance Tests** - Ensure no regression in suggestion speed

### Backward Compatibility

All enhancements should:
- Maintain existing API contracts
- Not break current functionality
- Degrade gracefully when schema info unavailable
- Support incremental adoption

---

## Success Metrics

### After Option B Implementation

**Quantitative:**
- Test coverage: 113+ tests (up from 68)
- Code coverage: Maintain >90% for new code
- Performance: No degradation (<10ms suggestion generation)

**Qualitative:**
- Users can write complex multi-table queries efficiently
- Alias-based suggestions feel natural and intuitive
- JOIN ON suggestions reduce typing by ~40% in complex queries
- Subquery support enables advanced query patterns

### User Satisfaction Goals

- Reduce "why doesn't this work?" moments by 80%
- Increase perceived editor quality from "good" to "excellent"
- Match or exceed expectations from professional SQL tools
- Enable users to write production queries without switching editors

---

## Next Steps

### To Implement Option B:

1. **Phase 1: Single Quote Support** (Quickest win)
   - Extend quote detection
   - Add 8 tests
   - 1-2 days

2. **Phase 2: Table Alias Support** (Highest impact)
   - Implement alias parsing
   - Add alias→table mapping
   - Add 15 tests
   - 3-4 days

3. **Phase 3: JOIN ON Matching** (User delight)
   - Implement ON clause detection
   - Add smart column suggestions
   - Add 10 tests
   - 2-3 days

4. **Phase 4: Subquery Context** (Advanced users)
   - Implement nested SELECT detection
   - Add context tracking
   - Add 12 tests
   - 4-5 days

**Total Estimated Time:** 10-14 days

---

## Conclusion

The current SQL editor implementation is **already very good** (7.5/10) with world-class features in multi-word handling, function autocomplete, and cross-platform support.

**Option B enhancements** would elevate it to **professional-grade** (8.5/10), addressing the critical gaps that experienced SQL developers notice daily.

This roadmap provides a clear path to becoming a **go-to SQL editing solution** while maintaining the excellent foundation already in place.

---

*Document created: 2025*
*Last updated: 2025*
*Status: Planning phase*
