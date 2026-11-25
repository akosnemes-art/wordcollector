#!/usr/bin/env python3
"""Build the offline bilingual lookup from Kaikki's Hungarian Wiktionary JSONL."""

import argparse
import bz2
from collections import defaultdict
import gzip
import json
from pathlib import Path
import re
import unicodedata


DATED_TAGS = {
    'abbreviation', 'alt-of', 'archaic', 'dated', 'dialectal', 'historical',
    'nonstandard', 'obsolete', 'rare', 'regional',
}
SPECIALIZED_TAGS = {'childish', 'derogatory', 'figuratively', 'slang', 'vulgar'}
PARTS_OF_SPEECH = {'adj', 'adv', 'conj', 'det', 'intj', 'noun', 'num', 'particle',
                   'phrase', 'postp', 'prep', 'pron', 'proverb', 'verb'}
IRREGULAR_PLURALS = {
    'child': 'children', 'foot': 'feet', 'goose': 'geese', 'man': 'men',
    'mouse': 'mice', 'person': 'people', 'tooth': 'teeth', 'woman': 'women',
    'deer': 'deer', 'fish': 'fish', 'sheep': 'sheep',
}


def key(text):
    return ' '.join(unicodedata.normalize('NFC', text).lower().replace('’', "'").split())


def equivalents(gloss):
    if match := re.match(r'^synonym of .+?\(“([^”]+)”\)', gloss, flags=re.I):
        gloss = match[1]
    else:
        # Parentheses contain sense descriptions and usage notes in this dump.
        while (shorter := re.sub(r'\([^()]*\)', ' ', gloss)) != gloss:
            gloss = shorter
    gloss = re.sub(r'^to\s+', '', gloss.strip(), flags=re.I)
    for term in re.split(r'[,;]', gloss):
        term = ' '.join(term.split()).strip(' .!?:')
        if not re.fullmatch(r"[^\W_]+(?:[-'’ ][^\W_]+){0,5}", term):
            continue
        if re.search(r'\b(?:alternative form|form of|synonym of|plural of|type of|kind of|someone|something|that|which)\b', term, re.I):
            continue
        if term.lower().startswith(('a ', 'an ', 'the ')):
            continue
        yield term


def pluralize(term):
    head, _, noun = term.rpartition(' ')
    if not re.fullmatch(r'[a-z]+', noun):
        return None
    if noun in IRREGULAR_PLURALS:
        plural = IRREGULAR_PLURALS[noun]
    elif noun.endswith(('ch', 'sh', 'ss', 'x', 'z')):
        plural = noun + 'es'
    elif noun.endswith('y') and len(noun) > 1 and noun[-2] not in 'aeiou':
        plural = noun[:-1] + 'ies'
    elif noun.endswith('s') or noun.endswith(('f', 'fe', 'o')):
        return None
    else:
        plural = noun + 's'
    return f'{head} {plural}' if head else plural


def add(index, source, translation, rank):
    translations = index[source]
    normalized = key(translation)
    current = translations.get(normalized)
    if current is None or rank < current[0]:
        translations[normalized] = (rank, translation)


def turtle_string(value, language):
    match = re.match(r'("(?:[^"\\]|\\.)*")@' + language + r'\b', value)
    if not match:
        return None
    literal = re.sub(r'\\U([0-9a-fA-F]{8})', lambda m: chr(int(m[1], 16)), match[1])
    try:
        return json.loads(literal.replace("\\'", "'"))
    except json.JSONDecodeError:
        return None


def read_dbnary(path):
    # The official Turtle dump gives each form and translation its own block.
    forms = {}
    translations = []
    subject = ''
    entry = None
    word = None
    usage = ''
    with bz2.open(path, 'rt', encoding='utf-8') as data:
        for line in data:
            if line.startswith('eng:'):
                subject = line.split(maxsplit=1)[0]
                entry, word, usage = None, None, ''
            elif not line.strip():
                if subject.startswith('eng:__tr_hun_') and entry and word:
                    order = int(subject.removeprefix('eng:__tr_hun_').split('_', 1)[0])
                    translations.append((entry, word, order, usage))
                subject = ''
            elif subject.startswith('eng:__cf_') and 'ontolex:writtenRep' in line:
                spelling = turtle_string(line.split('ontolex:writtenRep', 1)[1].strip(), 'en')
                if spelling:
                    forms[subject.removeprefix('eng:__cf_')] = spelling
            elif subject.startswith('eng:__tr_hun_'):
                field, _, value = line.strip().partition(' ')
                value = value.strip()
                if field == 'dbnary:isTranslationOf' and value.startswith('eng:'):
                    entry = value.split(maxsplit=1)[0].removeprefix('eng:').rstrip(';')
                elif field == 'dbnary:writtenForm':
                    word = turtle_string(value, 'hu')
                elif field == 'dbnary:usage':
                    usage = value.lower()
    for entry, word, order, usage in translations:
        if source := forms.get(entry):
            yield source, word, order, usage


def build(path, frequencies, dbnary):
    hungarian = defaultdict(dict)
    english = defaultdict(dict)
    noun_forms = []
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt', encoding='utf-8') as entries:
        for line in entries:
            entry = json.loads(line)
            pos = entry.get('pos')
            if entry.get('lang_code') != 'hu' or pos not in PARTS_OF_SPEECH:
                continue
            word = entry['word']
            word_key = key(word)
            if not word_key or word.startswith('-') or word.endswith('-'):
                continue
            for sense_order, sense in enumerate(entry.get('senses', [])):
                tags = set(sense.get('tags', []))
                if tags & DATED_TAGS:
                    continue
                forms = sense.get('form_of', [])
                if forms and pos == 'noun' and (tags & {'accusative', 'nominative'}) and (tags & {'plural', 'singular'}):
                    noun_forms.append((word, forms[0]['word'], 'plural' in tags))
                    continue
                glosses = [form['extra'] for form in forms if form.get('extra')]
                if not forms:
                    glosses = sense.get('glosses', [])[-1:]
                for gloss in glosses:
                    for term_order, term in enumerate(equivalents(gloss)):
                        marked = bool(tags & SPECIALIZED_TAGS)
                        add(hungarian, word_key, term, (marked, sense_order, term_order))
                        usage = frequencies.get(word_key, 0).bit_length()
                        add(english, key(term), word,
                            (1, marked, 2 * sense_order + term_order - usage, len(word)))

    for word, lemma, plural in noun_forms:
        word_key = key(word)
        if word_key in hungarian:
            continue
        for rank, term in hungarian.get(key(lemma), {}).values():
            equivalent = pluralize(term) if plural else term
            if equivalent is not None:
                add(hungarian, word_key, equivalent, rank)
                if plural:
                    marked, sense_order, term_order = rank
                    usage = frequencies.get(word_key, 0).bit_length()
                    add(english, key(equivalent), word,
                        (1, marked, 2 * sense_order + term_order - usage, len(word)))

    imported = 0
    for source, term, order, usage in read_dbnary(dbnary):
        source_key, target_key = key(source), key(term)
        if not source_key or not target_key or source_key.startswith('-'):
            continue
        if any(tag in usage for tag in DATED_TAGS):
            continue
        marked = any(tag in usage for tag in SPECIALIZED_TAGS)
        frequency = frequencies.get(target_key, 0).bit_length()
        confirmed = source_key in hungarian.get(target_key, {})
        rank = (0, marked, 2 * min(order - 1, 12) - frequency, not confirmed, len(term))
        add(english, source_key, term, rank)
        imported += 1
    if imported < 50_000:
        raise ValueError(f'Expected the full DBnary extract, found {imported:,} English–Hungarian translations')
    print(f'DBnary: {imported:,} English–Hungarian translations')

    ranked = {
        language: {
            word: [translation for _, translation in sorted(translations.values())[:6]]
            for word, translations in sorted(index.items())
        }
        for language, index in (('hu', hungarian), ('en', english))
    }
    return clean_display_terms(ranked)


def clean_display_terms(ranked):
    links = re.compile(r'\[\[([^\[\]|]+)(?:\|([^\[\]]+))?\]\]')
    markup = re.compile(r'[\[\]{}<>]')
    data = {}
    for language, index in ranked.items():
        words = {}
        for word, options in index.items():
            if markup.search(word):
                continue
            cleaned = {}
            for term in options:
                term = links.sub(lambda match: match[2] or match[1], term)
                term = ' '.join(term.split())
                if term and not markup.search(term):
                    cleaned.setdefault(key(term), term)
            if cleaned:
                words[word] = list(cleaned.values())
        data[language] = words
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='Hungarian Wiktionary JSONL (optionally gzipped)')
    parser.add_argument('frequencies', type=Path, help='FrequencyWords hu_50k.txt')
    parser.add_argument('dbnary', type=Path, help='English DBnary ontolex .ttl.bz2')
    parser.add_argument('output', type=Path, help='Output .json.gz file')
    args = parser.parse_args()
    with args.frequencies.open(encoding='utf-8') as counts:
        frequencies = {word: int(count) for word, count in map(str.split, counts)}
    data = build(args.input, frequencies, args.dbnary)
    with args.output.open('wb') as output:
        payload = json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode()
        output.write(gzip.compress(payload, mtime=0))
    for language, entries in data.items():
        print(f'{language}: {len(entries):,} lookup keys')


if __name__ == '__main__':
    main()
