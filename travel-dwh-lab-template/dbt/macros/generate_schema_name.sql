{#-
    prod  -> staging / intermediate / marts (nombres limpios)
    dev   -> dbt_dev_staging, dbt_dev_marts...
    ci    -> ci_pr_42_staging, ci_pr_42_marts... (fáciles de borrar por prefijo)
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
