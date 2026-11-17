{#-
    Limpieza de esquemas efímeros de CI.
    dbt run-operation drop_schemas_by_prefix --args '{prefix: ci_pr_42}'
-#}
{% macro drop_schemas_by_prefix(prefix) %}
    {% if target.name == 'prod' %}
        {{ exceptions.raise_compiler_error("drop_schemas_by_prefix no se ejecuta contra prod") }}
    {% endif %}
    {% if prefix | length < 5 %}
        {{ exceptions.raise_compiler_error("Prefijo demasiado corto: '" ~ prefix ~ "'") }}
    {% endif %}

    {% set find_schemas %}
        select schema_name
        from {{ target.database }}.information_schema.schemata
        where schema_name ilike '{{ prefix }}%'
    {% endset %}

    {% if execute %}
        {% set schemas = run_query(find_schemas).columns[0].values() %}
        {% for schema in schemas %}
            {% do run_query("drop schema if exists " ~ target.database ~ "." ~ schema ~ " cascade") %}
            {{ log("Eliminado " ~ target.database ~ "." ~ schema, info=True) }}
        {% endfor %}
        {% if schemas | length == 0 %}
            {{ log("No hay esquemas con prefijo " ~ prefix, info=True) }}
        {% endif %}
    {% endif %}
{% endmacro %}
