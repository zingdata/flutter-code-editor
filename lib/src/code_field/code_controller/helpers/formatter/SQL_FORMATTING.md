# SQL Formatting and Autocompletion Logic

This document explains the SQL-specific formatting and autocompletion logic in the Flutter Code Editor. The implementation is designed to provide intelligent, context-aware text formatting and suggestions specifically for SQL code.

## Core Components

The SQL formatting functionality is divided into several key components:

1. **SqlFormatter**: A utility class with static methods for handling SQL-specific text formatting
2. **SQL Context Detection**: Methods for detecting when the user is in a specific SQL context (e.g., after table.)
3. **Format Specialization**: Different formatting rules based on SQL element types (functions, tables, columns, etc.)
4. **Space Handling**: Logic for determining when to add spaces in SQL expressions
5. **Cursor Positioning**: Smart cursor placement based on what was inserted
6. **Multi-Word Identifier Handling**: Special handling for SQL identifiers containing spaces

## SQL Formatter Class

The `SqlFormatter` class provides a centralized API for handling all SQL-specific formatting needs. Its main entry point is the `formatSql` method, which analyzes the context and applies appropriate formatting rules.

### Key Features

- **Context Detection**: Analyzes text before and after insertion point to make formatting decisions
- **SQL Pattern Recognition**: Identifies common SQL patterns like table names, functions, and column references
- **Smart Formatting**: Applies different formatting rules based on the type of SQL element being inserted
- **Cursor Positioning**: Places cursor in logical position based on context (e.g., inside function parentheses)
- **Multi-Word Support**: Properly formats identifiers containing spaces with appropriate quoting

## Context Detection

The formatter detects several important context scenarios:

### Column Context

Detected when:
- Text ends with a period (suggesting we're typing after `table.`)
- Used to know when to format as a column name vs. a table name

```sql
SELECT * FROM users.  -- Cursor here is in column context
```

### Function Call Context

Detected when:
- Inside unbalanced parentheses
- Used to avoid adding duplicate parentheses in function calls

```sql
COUNT(  -- Cursor here is in function call context
```

### SQL Expression Context

Detected when:
- Next character is an operator or part of an expression
- Used to determine whether to add spaces

```sql
column_name=  -- Cursor here is in expression context
```

### Multi-Word Identifier Context

Detected when:
- Working with identifiers containing spaces
- Used for appropriate quoting and boundary detection

```sql
"Customer  -- Cursor here is in multi-word identifier context
```

## Specialized Formatting

The formatter handles different SQL elements differently:

### Aggregation Functions

For functions like SUM, COUNT, MIN, MAX, AVG:
- Adds `()` automatically (unless already in function context)
- Positions cursor inside parentheses for convenience

### Table Names

For table names:
- Adds quotes if configured and not already quoted
- Automatically adds quotes if table name contains spaces (e.g., `"Pet Type"`)
- Adds a dot after table names if configured (and not already present)
- Marks as "isTable" to trigger column suggestions

### Column Names

For columns (after table.):
- Doesn't add quotes in this context unless needed for spaces
- Adds space only if not in the middle of an expression
- Auto-quotes column names with spaces (e.g., `"Customer Name"`)

### Multi-Word Identifiers

For identifiers containing spaces:
- Always adds quotes (typically double quotes in SQL)
- Preserves spaces within the identifier
- Ensures proper SQL syntax even with complex identifiers

### Identifiers

For general identifiers:
- Adds quotes if configured and not a reserved keyword
- Adds space after if appropriate

### SQL Keywords

For keywords like SELECT, FROM, WHERE:
- Uppercases keywords (optional)
- Always adds space after keywords

## Multi-Word Identifier Support

The system includes special handling for multi-word identifiers that are common in database schemas:

### Detection and Replacement

- When a user is typing part of a multi-word identifier (e.g., "pet ty" for "Pet Type"), the suggestion system identifies this as a partial match of a multi-word entity
- The word insertion helper ensures the entire phrase is replaced, not just the part after the space
- This prevents SQL syntax errors and maintains identifier integrity

### Formatting Rules

- Multi-word identifiers are automatically quoted in SQL: `"Pet Type"` instead of `Pet Type`
- Spaces between words are preserved within the quotes
- The formatter adjusts cursor position appropriately after inserting a multi-word identifier

### Example Flow

```
User types: pet ty
Suggestion shows: Pet Type
When selected, what gets inserted: "Pet Type"
What gets replaced: pet ty (the entire partial match)
```

## Design Principles

1. **Context Awareness**: Formatting decisions are based on the surrounding context, not just the word itself
2. **Prevention of Duplicates**: The formatter avoids adding duplicated characters (quotes, dots, parentheses)
3. **SQL Standards**: Formatting follows common SQL coding standards
4. **Customizability**: Behavior can be customized through parameters like `needsQuotes` and `needDotForTable`
5. **Semantic Unity**: Treats multi-word identifiers as a single semantic unit

## Integration

The SQL formatter is integrated with the code editor through:

1. The `formatAndAdjustOffset` method in `CodeController`, which delegates to `SqlFormatter`
2. The autocompletion system, which uses SQL context detection to show relevant suggestions
3. The `WordInsertionHelper`, which handles replacement of text with suggestions

## Table-Column Relationship

The formatter and autocompletion system work together to provide an intelligent experience when working with tables and columns:

1. After selecting a table name, a dot is automatically added
2. After typing a dot after a table name, column suggestions for that specific table are shown
3. When the user continues typing after the dot, the suggestions are filtered to match what's been typed
4. Multi-word table and column names are properly quoted and formatted

## Extensibility

The system is designed to be extensible:

1. New SQL patterns can be added by extending the context detection methods
2. Formatting rules can be modified for different SQL dialects
3. The SQL keywords and functions lists can be extended for broader coverage
4. Support for different quoting styles can be added for different SQL dialects

## Related Components

- **AutoCompleter**: Works with the SQL formatter to provide context-aware suggestions
- **PopupController**: Displays suggestions based on SQL context
- **SuggestionHelper**: Uses SQL context to determine what suggestions to show and how to match them
- **WordInsertionHelper**: Handles the insertion of suggestions, including multi-word identifiers

This implementation ensures that the editor provides a smooth, intuitive experience for writing SQL queries, with intelligent formatting and suggestions that reflect SQL's unique syntax requirements, including proper handling of identifiers containing spaces. 