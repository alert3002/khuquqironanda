"""
AI utilities for book search functionality.
Handles embeddings, FAISS index operations, and OpenAI interactions.
"""
import os
from pathlib import Path
from typing import List, Tuple, Optional
import re

# Langchain imports - compatible with version 0.1.0
try:
    # Try newer langchain structure (0.2.0+)
    from langchain_openai import OpenAIEmbeddings, ChatOpenAI
    from langchain_community.vectorstores import FAISS
except ImportError:
    # Fallback to older langchain structure (0.1.0)
    from langchain.embeddings.openai import OpenAIEmbeddings
    from langchain.chat_models import ChatOpenAI
    from langchain.vectorstores import FAISS

from langchain.text_splitter import RecursiveCharacterTextSplitter
try:
    from langchain_core.prompts import ChatPromptTemplate, SystemMessagePromptTemplate, HumanMessagePromptTemplate
except ImportError:
    from langchain.prompts import ChatPromptTemplate, SystemMessagePromptTemplate, HumanMessagePromptTemplate
from django.conf import settings

# Path to store FAISS index
FAISS_INDEX_DIR = Path(settings.BASE_DIR) / 'faiss_index'


def clean_html_content(text: str) -> str:
    """
    Remove HTML tags from content (since Chapter.content uses RichTextUploadingField).
    """
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    # Decode HTML entities
    import html
    text = html.unescape(text)
    # Clean up extra whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def split_text_into_chunks(text: str, chunk_size: int = 1000, chunk_overlap: int = 200) -> List[str]:
    """
    Split text into chunks of approximately chunk_size characters.
    """
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        length_function=len,
        separators=["\n\n", "\n", ". ", " ", ""]
    )
    chunks = text_splitter.split_text(text)
    return chunks


def get_embeddings():
    """
    Initialize and return OpenAI embeddings instance.
    Requires OPENAI_API_KEY in settings or environment.
    """
    api_key = getattr(settings, 'OPENAI_API_KEY', None) or os.getenv('OPENAI_API_KEY')
    if not api_key:
        raise ValueError("OPENAI_API_KEY must be set in Django settings or environment variables")
    
    return OpenAIEmbeddings(openai_api_key=api_key)


def create_faiss_index(chapters_data: List[Tuple[str, str, str, str]]):
    """
    Create FAISS index from chapter data.
    
    Args:
        chapters_data: List of tuples (book_title, chapter_title, chapter_content, chapter_id)
    """
    # Ensure directory exists
    FAISS_INDEX_DIR.mkdir(parents=True, exist_ok=True)
    
    # Get embeddings
    embeddings = get_embeddings()
    
    # Prepare documents
    documents = []
    metadatas = []
    
    for book_title, chapter_title, content, chapter_id in chapters_data:
        # Skip if content is empty or None
        if not content:
            continue
            
        # Clean HTML from content
        clean_content = clean_html_content(str(content))
        
        # Skip if cleaned content is empty
        if not clean_content.strip():
            continue
        
        # Split into chunks
        chunks = split_text_into_chunks(clean_content)
        
        for i, chunk in enumerate(chunks):
            # Create document with metadata
            doc_text = f"Book: {book_title}\nChapter: {chapter_title}\n\n{chunk}"
            documents.append(doc_text)
            metadatas.append({
                'book_title': book_title,
                'chapter_title': chapter_title,
                'chapter_id': chapter_id,
                'chunk_index': i
            })
    
    # Create FAISS vector store
    vectorstore = FAISS.from_texts(
        texts=documents,
        embedding=embeddings,
        metadatas=metadatas
    )
    
    # Save to disk
    vectorstore.save_local(str(FAISS_INDEX_DIR))
    
    return len(documents)


def load_faiss_index():
    """
    Load FAISS index from disk.
    """
    if not FAISS_INDEX_DIR.exists() or not (FAISS_INDEX_DIR / 'index.faiss').exists():
        raise FileNotFoundError(
            f"FAISS index not found at {FAISS_INDEX_DIR}. "
            "Please run 'python manage.py process_books' first."
        )
    
    embeddings = get_embeddings()
    # Try with allow_dangerous_deserialization for newer versions, fallback for older
    try:
        vectorstore = FAISS.load_local(str(FAISS_INDEX_DIR), embeddings, allow_dangerous_deserialization=True)
    except TypeError:
        # Older version doesn't have allow_dangerous_deserialization parameter
        vectorstore = FAISS.load_local(str(FAISS_INDEX_DIR), embeddings)
    return vectorstore


def search_relevant_chunks(query: str, top_k: int = 3) -> List[dict]:
    """
    Search for top_k most relevant chunks matching the query.
    
    Returns:
        List of dicts with keys: 'content', 'book_title', 'chapter_title', 'chapter_id', 'score'
    """
    vectorstore = load_faiss_index()
    
    # Search for similar documents
    results = vectorstore.similarity_search_with_score(query, k=top_k)
    
    chunks = []
    for doc, score in results:
        metadata = doc.metadata
        chunks.append({
            'content': doc.page_content,
            'book_title': metadata.get('book_title', 'Unknown'),
            'chapter_title': metadata.get('chapter_title', 'Unknown'),
            'chapter_id': metadata.get('chapter_id', ''),
            'score': float(score)
        })
    
    return chunks


def get_ai_answer(query: str, context_chunks: List[dict]) -> Tuple[str, str]:
    """
    Get AI answer based on query and context chunks.
    
    Args:
        query: User's question
        context_chunks: List of relevant chunks from search
        
    Returns:
        Tuple of (answer, source_book)
    """
    # Prepare context from chunks
    context_text = "\n\n---\n\n".join([
        f"From '{chunk['book_title']}' - Chapter: '{chunk['chapter_title']}':\n{chunk['content']}"
        for chunk in context_chunks
    ])
    
    # Get source book (use the first chunk's book as primary source)
    source_book = context_chunks[0]['book_title'] if context_chunks else "Unknown"
    
    # Create prompt template
    system_template = (
        "You are a helpful assistant. Answer the user's question using ONLY the provided context from the books. "
        "If the answer is not in the context, say 'I don't know'. "
        "Do not make up information or use knowledge outside of the provided context."
    )
    
    human_template = (
        "Context from books:\n{context}\n\n"
        "User question: {query}\n\n"
        "Answer:"
    )
    
    system_prompt = SystemMessagePromptTemplate.from_template(system_template)
    human_prompt = HumanMessagePromptTemplate.from_template(human_template)
    
    chat_prompt = ChatPromptTemplate.from_messages([system_prompt, human_prompt])
    
    # Get OpenAI API key
    api_key = getattr(settings, 'OPENAI_API_KEY', None) or os.getenv('OPENAI_API_KEY')
    if not api_key:
        raise ValueError("OPENAI_API_KEY must be set in Django settings or environment variables")
    
    # Initialize chat model
    try:
        # Try newer API (model parameter)
        llm = ChatOpenAI(
            model="gpt-3.5-turbo",
            temperature=0,
            openai_api_key=api_key
        )
    except TypeError:
        # Fallback to older API (model_name parameter)
        llm = ChatOpenAI(
            model_name="gpt-3.5-turbo",
            temperature=0,
            openai_api_key=api_key
        )
    
    # Generate answer
    messages = chat_prompt.format_prompt(
        context=context_text,
        query=query
    ).to_messages()
    
    response = llm(messages)
    answer = response.content
    
    return answer, source_book

