import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="Regulatory Intelligence",
    page_icon="📋",
    layout="wide",
)

@st.cache_resource
def get_session():
    return get_active_session()

@st.cache_data(ttl=600)
def load_regulations():
    session = get_session()
    return session.sql("""
        SELECT 
            document_number, title, document_type, primary_agency,
            publication_date, regulatory_category, affected_company_count,
            related_filing_count, ai_summary, html_url, abstract
        FROM REG_INTEL.ANALYTICS.DT_REG_GOLD_ENRICHED
        ORDER BY publication_date DESC
    """).to_pandas()

@st.cache_data(ttl=600)
def load_regulation_detail(doc_number: str):
    session = get_session()
    return session.sql(f"""
        SELECT *
        FROM REG_INTEL.ANALYTICS.DT_REG_GOLD_ENRICHED
        WHERE document_number = '{doc_number}'
    """).to_pandas()

@st.cache_data(ttl=600)
def load_affected_companies(doc_number: str):
    session = get_session()
    return session.sql(f"""
        SELECT company_name, primary_ticker, sec_industry_group
        FROM REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE
        WHERE document_number = '{doc_number}'
        ORDER BY company_name
        LIMIT 100
    """).to_pandas()

@st.cache_data(ttl=600)
def load_related_filings(doc_number: str):
    session = get_session()
    return session.sql(f"""
        SELECT filing_company, form_type, filed_date, primary_ticker
        FROM REG_INTEL.ANALYTICS.DT_REG_SEC_FILINGS
        WHERE document_number = '{doc_number}'
        ORDER BY filed_date DESC
        LIMIT 50
    """).to_pandas()

@st.cache_data(ttl=600)
def load_category_stats():
    session = get_session()
    return session.sql("""
        SELECT 
            regulatory_category,
            COUNT(*) as reg_count,
            SUM(affected_company_count) as total_exposure
        FROM REG_INTEL.ANALYTICS.DT_REG_GOLD_ENRICHED
        GROUP BY regulatory_category
        ORDER BY reg_count DESC
    """).to_pandas()

@st.cache_data(ttl=600)
def load_companies():
    session = get_session()
    return session.sql("""
        SELECT DISTINCT company_name, primary_ticker
        FROM REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE
        WHERE primary_ticker IS NOT NULL
        ORDER BY company_name
        LIMIT 1000
    """).to_pandas()

@st.cache_data(ttl=600)
def load_company_regulations(ticker: str):
    session = get_session()
    return session.sql(f"""
        SELECT 
            document_number, regulation_title, regulatory_category,
            publication_date, sec_industry_group
        FROM REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE
        WHERE primary_ticker = '{ticker}'
        ORDER BY publication_date DESC
    """).to_pandas()

@st.cache_data(ttl=600)
def load_company_filings(ticker: str):
    session = get_session()
    return session.sql(f"""
        SELECT 
            document_number, regulation_title, form_type,
            filed_date, filing_company
        FROM REG_INTEL.ANALYTICS.DT_REG_SEC_FILINGS
        WHERE primary_ticker = '{ticker}'
        ORDER BY filed_date DESC
        LIMIT 50
    """).to_pandas()

# Check for URL parameter - direct link to regulation detail
query_params = st.query_params
doc_param = query_params.get("doc", None)

if doc_param:
    # REGULATION DETAIL VIEW
    reg = load_regulation_detail(doc_param)
    
    if reg.empty:
        st.error(f"Regulation {doc_param} not found")
        if st.button("← Back to Dashboard"):
            st.query_params.clear()
            st.rerun()
    else:
        reg.columns = reg.columns.str.lower()
        r = reg.iloc[0]
        
        if st.button("← Back to Dashboard"):
            st.query_params.clear()
            st.rerun()
        
        st.title(f"📋 {r['title']}")
        
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Document #", r['document_number'])
        col2.metric("Type", r['document_type'])
        col3.metric("Category", r['regulatory_category'])
        col4.metric("Published", str(r['publication_date'])[:10])
        
        st.divider()
        
        col1, col2 = st.columns(2)
        col1.metric("Companies Affected", f"{int(r['affected_company_count']):,}")
        col2.metric("Related SEC Filings", f"{int(r['related_filing_count']):,}")
        
        if r.get('abstract'):
            st.subheader("Abstract")
            st.write(r['abstract'])
        
        if r.get('ai_summary'):
            st.subheader("AI Summary")
            st.info(r['ai_summary'])
        
        if r.get('html_url'):
            st.markdown(f"[📄 View on Federal Register]({r['html_url']})")
        
        st.divider()
        
        tab1, tab2 = st.tabs(["Affected Companies", "Related SEC Filings"])
        
        with tab1:
            companies = load_affected_companies(doc_param)
            if not companies.empty:
                companies.columns = companies.columns.str.lower()
                st.dataframe(companies, use_container_width=True, hide_index=True)
            else:
                st.info("No affected companies found.")
        
        with tab2:
            filings = load_related_filings(doc_param)
            if not filings.empty:
                filings.columns = filings.columns.str.lower()
                st.dataframe(filings, use_container_width=True, hide_index=True)
            else:
                st.info("No related SEC filings found.")

else:
    # MAIN DASHBOARD VIEW
    regulations = load_regulations()
    regulations.columns = regulations.columns.str.lower()

    with st.sidebar:
        st.title("🔍 Filters")
        
        categories = ["All"] + sorted(regulations["regulatory_category"].dropna().unique().tolist())
        selected_category = st.selectbox("Category", categories)
        
        doc_types = ["All"] + sorted(regulations["document_type"].dropna().unique().tolist())
        selected_doc_type = st.selectbox("Document Type", doc_types)
        
        min_companies = st.slider("Min. Affected Companies", 0, 2000, 0, 50)
        
        st.divider()
        page = st.radio("Navigate", ["📊 Overview", "🏢 Company Explorer"], label_visibility="collapsed")

    filtered = regulations.copy()
    if selected_category != "All":
        filtered = filtered[filtered["regulatory_category"] == selected_category]
    if selected_doc_type != "All":
        filtered = filtered[filtered["document_type"] == selected_doc_type]
    filtered = filtered[filtered["affected_company_count"] >= min_companies]

    if page == "📊 Overview":
        st.title("📋 Regulatory Intelligence Dashboard")
        st.caption("Federal Register regulations enriched with company exposure data")
        
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Total Regulations", f"{len(filtered):,}")
        col2.metric("Unique Categories", filtered["regulatory_category"].nunique())
        col3.metric("Companies Affected", f"{filtered['affected_company_count'].sum():,.0f}")
        col4.metric("Related SEC Filings", f"{filtered['related_filing_count'].sum():,.0f}")
        
        st.divider()
        
        chart_col1, chart_col2 = st.columns(2)
        
        with chart_col1:
            st.subheader("Regulations by Category")
            cat_data = filtered.groupby("regulatory_category").size().reset_index(name="count")
            chart = alt.Chart(cat_data).mark_arc(innerRadius=50).encode(
                theta=alt.Theta("count:Q"),
                color=alt.Color("regulatory_category:N", legend=alt.Legend(orient="bottom", columns=2)),
                tooltip=["regulatory_category", "count"]
            ).properties(height=300)
            st.altair_chart(chart, use_container_width=True)
        
        with chart_col2:
            st.subheader("Regulations by Document Type")
            type_data = filtered.groupby("document_type").size().reset_index(name="count")
            chart = alt.Chart(type_data).mark_bar(color="#1a5f7a").encode(
                x=alt.X("count:Q", title="Count"),
                y=alt.Y("document_type:N", title=None, sort="-x"),
                tooltip=["document_type", "count"]
            ).properties(height=300)
            st.altair_chart(chart, use_container_width=True)
        
        st.subheader("Company Exposure by Category")
        exposure_data = load_category_stats()
        exposure_data.columns = exposure_data.columns.str.lower()
        chart = alt.Chart(exposure_data).mark_bar(color="#2d8cb8").encode(
            x=alt.X("total_exposure:Q", title="Total Companies Affected"),
            y=alt.Y("regulatory_category:N", title=None, sort="-x"),
            tooltip=["regulatory_category", "total_exposure", "reg_count"]
        ).properties(height=300)
        st.altair_chart(chart, use_container_width=True)
        
        st.subheader("Recent High-Impact Regulations")
        display_df = filtered.nlargest(20, "affected_company_count")[
            ["document_number", "title", "regulatory_category", "document_type", 
             "publication_date", "affected_company_count", "related_filing_count"]
        ].copy()
        display_df.columns = ["Doc #", "Title", "Category", "Type", "Date", "Companies", "SEC Filings"]
        
        st.dataframe(
            display_df, 
            use_container_width=True, 
            hide_index=True,
            column_config={
                "Doc #": st.column_config.TextColumn("Doc #", width="small"),
            }
        )
        st.caption("💡 Click a document number in the table, then add `?doc=XXXX-XXXXX` to the URL to view details")

    elif page == "🏢 Company Explorer":
        st.title("🏢 Company Explorer")
        st.caption("Find regulations and SEC filings affecting specific companies")
        
        companies = load_companies()
        companies.columns = companies.columns.str.lower()
        
        company_options = companies.apply(
            lambda x: f"{x['primary_ticker']} - {x['company_name']}", axis=1
        ).tolist()
        
        selected = st.selectbox("Search Company", [""] + company_options, 
                               help="Select a company to see regulations affecting it")
        
        if selected:
            ticker = selected.split(" - ")[0]
            company_name = selected.split(" - ")[1]
            
            st.subheader(f"📊 {company_name} ({ticker})")
            
            tab1, tab2 = st.tabs(["Regulations", "SEC Filings"])
            
            with tab1:
                regs = load_company_regulations(ticker)
                if not regs.empty:
                    regs.columns = regs.columns.str.lower()
                    st.metric("Regulations Affecting This Company", len(regs))
                    st.dataframe(regs, use_container_width=True, hide_index=True)
                else:
                    st.info("No regulations found for this company.")
            
            with tab2:
                filings = load_company_filings(ticker)
                if not filings.empty:
                    filings.columns = filings.columns.str.lower()
                    st.metric("Related SEC Filings", len(filings))
                    st.dataframe(filings, use_container_width=True, hide_index=True)
                else:
                    st.info("No related SEC filings found.")
        else:
            st.info("👆 Select a company above to explore its regulatory exposure")
            
            st.subheader("Top Companies by Regulatory Exposure")
            session = get_session()
            top_companies = session.sql("""
                SELECT 
                    company_name, primary_ticker,
                    COUNT(DISTINCT document_number) as regulation_count,
                    COUNT(DISTINCT regulatory_category) as category_count
                FROM REG_INTEL.ANALYTICS.DT_COMPANY_EXPOSURE
                GROUP BY company_name, primary_ticker
                ORDER BY regulation_count DESC
                LIMIT 15
            """).to_pandas()
            top_companies.columns = top_companies.columns.str.lower()
            st.dataframe(top_companies, use_container_width=True, hide_index=True)
